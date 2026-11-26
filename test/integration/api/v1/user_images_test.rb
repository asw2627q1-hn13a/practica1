require "test_helper"

# API-16: PUT /api/v1/users/:id/images (multipart/form-data) and
# DELETE /api/v1/users/:id/images/:kind.
#
# Fixtures: no user has avatar or banner attached (the after_create_commit that
# attaches the defaults does not run for fixtures).
class Api::V1::UserImagesTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  # --- upload ---------------------------------------------------------------------------

  test "uploads an avatar and returns the profile with its new url" do
    put_images @alice, @alice, avatar: png

    assert_response :ok
    assert_match %r{application/json}, response.media_type
    assert_match %r{/rails/active_storage/blobs/redirect/.+/avatar\.png\z}, json["avatar_url"]
    assert_match %r{/assets/default_banner-\w+\.png\z}, json["banner_url"]
    assert_equal @alice.id, json["id"]
    assert_equal "alice@example.com", json["email"] # own profile
    assert_not_includes response.body, @alice.api_key
    assert @alice.reload.avatar.attached?
    assert_not @alice.banner.attached?
  end

  test "uploads an avatar and a banner in the same request" do
    put_images @alice, @alice, avatar: png, banner: png("banner.png")

    assert_response :ok
    assert_match %r{/avatar\.png\z}, json["avatar_url"]
    assert_match %r{/banner\.png\z}, json["banner_url"]
    assert @alice.reload.avatar.attached?
    assert @alice.banner.attached?
  end

  test "a new image replaces the previous one" do
    put_images @alice, @alice, avatar: png("first.png")
    first_blob_id = @alice.reload.avatar.blob.id
    put_images @alice, @alice, avatar: png("second.png")

    assert_response :ok
    assert_match %r{/second\.png\z}, json["avatar_url"]
    assert_not_equal first_blob_id, @alice.reload.avatar.blob.id
    assert_equal "second.png", @alice.avatar.filename.to_s
  end

  test "the other image is kept when only one is sent" do
    put_images @alice, @alice, banner: png("banner.png")
    put_images @alice, @alice, avatar: png("avatar.png")

    assert_response :ok
    assert_match %r{/avatar\.png\z}, json["avatar_url"]
    assert_match %r{/banner\.png\z}, json["banner_url"]
  end

  # --- validation (400 / 422) -----------------------------------------------------------

  test "without avatar nor banner is 400" do
    put_images @alice, @alice

    assert_response :bad_request
    assert_equal "bad_request", json["error"]
  end

  test "a file that is not an image is 422 and nothing is saved" do
    put_images @alice, @alice, avatar: upload(file_fixture("not_an_image.txt").to_s, "image/png")

    assert_response :unprocessable_content
    assert_equal "unprocessable_entity", json["error"]
    assert json["details"].key?("avatar")
    assert_not @alice.reload.avatar.attached?
  end

  test "an image over 5 MB is 422" do
    Tempfile.create([ "big", ".png" ], binmode: true) do |big|
      big.write(File.binread(file_fixture("avatar.png").to_s))
      big.write("0" * (User::MAX_IMAGE_SIZE + 1))
      big.flush
      put_images @alice, @alice, banner: upload(big.path, "image/png")
    end

    assert_response :unprocessable_content
    assert json["details"].key?("banner")
    assert_not @alice.reload.banner.attached?
  end

  test "it is all or nothing: a valid avatar is not saved if the banner is invalid" do
    put_images @alice, @alice,
               avatar: png,
               banner: upload(file_fixture("not_an_image.txt").to_s, "image/png")

    assert_response :unprocessable_content
    assert_equal [ "banner" ], json["details"].keys
    assert_not @alice.reload.avatar.attached?
    assert_not @alice.banner.attached?
  end

  test "a part that is not a file is 422" do
    put_images @alice, @alice, avatar: "http://example.com/avatar.png"

    assert_response :unprocessable_content
    assert json["details"].key?("avatar")
  end

  test "a JSON body is not accepted as a file upload" do
    put "/api/v1/users/#{@alice.id}/images",
        params: { avatar: "x" }.to_json,
        headers: { "X-API-KEY" => @alice.api_key, "Content-Type" => "application/json" }

    assert_response :unprocessable_content
    assert_not @alice.reload.avatar.attached?
  end

  # --- authentication, ownership and unknown user ---------------------------------------

  test "the images of another user cannot be changed: 403 and nothing changes" do
    put_images @alice, @bob, avatar: png

    assert_response :forbidden
    assert_equal "forbidden", json["error"]
    assert_equal "You can only modify your own profile", json["message"]
    assert_not @bob.reload.avatar.attached?
  end

  test "an unknown user is 404, before any other check" do
    put "/api/v1/users/0/images", params: { avatar: png }, headers: { "X-API-KEY" => @alice.api_key }

    assert_response :not_found
    assert_equal({ "error" => "not_found", "message" => "User with id=0 not found" }, json)
  end

  test "PUT requires an api-key, even if the user does not exist" do
    [ nil, "wrong" ].each do |key|
      [ @alice.id, 0 ].each do |id|
        put "/api/v1/users/#{id}/images", params: { avatar: png }, headers: { "X-API-KEY" => key }.compact

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
    assert_not @alice.reload.avatar.attached?
  end

  # --- reset to the default image -------------------------------------------------------

  test "DELETE goes back to the default image" do
    @alice.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")
    delete_image @alice, @alice, "avatar"

    assert_response :ok
    assert_match %r{/default_avatar\.png\z}, json["avatar_url"]
    assert_equal "default_avatar.png", @alice.reload.avatar.filename.to_s
  end

  test "DELETE of one image does not touch the other" do
    @alice.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")
    @alice.banner.attach(io: file_fixture("avatar.png").open, filename: "banner.png", content_type: "image/png")
    delete_image @alice, @alice, "banner"

    assert_response :ok
    assert_match %r{/avatar\.png\z}, json["avatar_url"]
    assert_match %r{/default_banner\.png\z}, json["banner_url"]
  end

  test "DELETE of an image that is already the default is 200" do
    delete_image @alice, @alice, "banner"

    assert_response :ok
    assert_match %r{/default_banner\.png\z}, json["banner_url"]
  end

  test "DELETE with another kind is 404" do
    delete_image @alice, @alice, "logo"

    assert_response :not_found
    assert_equal "not_found", json["error"]
  end

  test "DELETE on another user is 403 and nothing changes" do
    @bob.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")
    delete_image @alice, @bob, "avatar"

    assert_response :forbidden
    assert_equal "avatar.png", @bob.reload.avatar.filename.to_s
  end

  test "DELETE on an unknown user is 404" do
    delete "/api/v1/users/0/images/avatar", headers: { "X-API-KEY" => @alice.api_key }

    assert_response :not_found
  end

  test "DELETE requires an api-key" do
    delete "/api/v1/users/#{@alice.id}/images/avatar"

    assert_response :unauthorized
  end

  private

  def png(name = "avatar.png")
    upload(file_fixture("avatar.png").to_s, "image/png", name)
  end

  # binary = true: without it Rack::Test opens the file in text mode, which on
  # Windows converts the \r\n of the PNG header and corrupts the image.
  def upload(path, content_type, name = nil)
    Rack::Test::UploadedFile.new(path, content_type, true, original_filename: name)
  end

  # `as_user` is the user of the api-key; `target` the user of the URL.
  def put_images(as_user, target, **parts)
    put "/api/v1/users/#{target.id}/images", params: parts, headers: { "X-API-KEY" => as_user.api_key }
  end

  def delete_image(as_user, target, kind)
    delete "/api/v1/users/#{target.id}/images/#{kind}", headers: { "X-API-KEY" => as_user.api_key }
  end

  def json
    JSON.parse(response.body)
  end
end