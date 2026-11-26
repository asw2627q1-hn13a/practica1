require "test_helper"

# API-14: GET /api/v1/users/:id and its submissions, comments and favorites.
#
# Fixtures: alice has url_high (100 points) and ask_one (5 points), and the
# comments "first" and "on_low"; bob has url_low (10 points) and the comments
# "second" and "reply_to_first". There are no favorites in the fixtures and no
# user has avatar or banner attached (the after_create_commit does not run for
# fixtures).
class Api::V1::UsersTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  # --- profile ------------------------------------------------------------------

  test "any api-key gets the profile of another user, without email nor api-key" do
    @bob.update_columns(about: "Hi, I am bob")
    get_as @alice, "/api/v1/users/#{@bob.id}"

    assert_response :ok
    assert_match %r{application/json}, response.media_type
    assert_equal %w[id username about karma avatar_url banner_url created_at].sort, json.keys.sort
    assert_equal @bob.id, json["id"]
    assert_equal "bob", json["username"]
    assert_equal "Hi, I am bob", json["about"]
    assert_equal 10, json["karma"]
    assert_equal @bob.created_at.utc.iso8601, json["created_at"]
    assert_not_includes response.body, @bob.api_key
    assert_not_includes response.body, @bob.email
  end

  test "the own profile also includes the email, but never the api-key" do
    get_as @alice, "/api/v1/users/#{@alice.id}"

    assert_response :ok
    assert_equal "alice@example.com", json["email"]
    assert_equal 105, json["karma"] # 100 + 5
    assert_not_includes response.body, @alice.api_key
  end

  test "about and email can be null" do
    @alice.update_columns(about: nil, email: nil)
    get_as @alice, "/api/v1/users/#{@alice.id}"

    assert_response :ok
    assert_nil json["about"]
    assert json.key?("email")
    assert_nil json["email"]
  end

  test "without images attached, the urls are the absolute urls of the default images" do
    get_as @alice, "/api/v1/users/#{@bob.id}"

    assert_match %r{\Ahttp://www\.example\.com/assets/default_avatar-\w+\.png\z}, json["avatar_url"]
    assert_match %r{\Ahttp://www\.example\.com/assets/default_banner-\w+\.png\z}, json["banner_url"]
  end

  test "with an image attached, its url is the absolute url of the attached file" do
    @bob.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")
    get_as @alice, "/api/v1/users/#{@bob.id}"

    assert_match %r{\Ahttp://www\.example\.com/rails/active_storage/blobs/redirect/.+/avatar\.png\z}, json["avatar_url"]
    assert_match %r{/assets/default_banner-\w+\.png\z}, json["banner_url"]
  end

  # --- submissions and comments ---------------------------------------------------------

  test "submissions: the user's submissions, newest first" do
    submissions(:ask_one).update_columns(created_at: 2.days.ago)
    submissions(:url_high).update_columns(created_at: 1.day.ago)
    get_as @bob, "/api/v1/users/#{@alice.id}/submissions"

    assert_response :ok
    assert_equal [ submissions(:url_high).id, submissions(:ask_one).id ], json.map { |s| s["id"] }
    assert_equal %w[id title url domain text submission_type points comments_count user created_at updated_at].sort,
                 json.first.keys.sort
    assert(json.all? { |s| s["user"] == { "id" => @alice.id, "username" => "alice" } })
  end

  test "submissions: the ones the api-key user has hidden are not excluded" do
    Hide.create!(user: @bob, submission: submissions(:url_high))
    get_as @bob, "/api/v1/users/#{@alice.id}/submissions"

    assert_includes json.map { |s| s["id"] }, submissions(:url_high).id
  end

  test "comments: the user's comments, newest first, flat and with their submission" do
    comments(:first).update_columns(created_at: 2.days.ago)
    comments(:on_low).update_columns(created_at: 1.day.ago)
    get_as @bob, "/api/v1/users/#{@alice.id}/comments"

    assert_response :ok
    assert_equal [ comments(:on_low).id, comments(:first).id ], json.map { |c| c["id"] }
    assert_equal({ "id" => submissions(:url_low).id, "title" => submissions(:url_low).title }, json.first["submission"])
    assert_not json.first.key?("replies")
    assert(json.all? { |c| c["user"]["id"] == @alice.id })
  end

  # --- favorites ------------------------------------------------------------------------

  test "favorites/submissions: most recently favorited first, not by the submission date" do
    Favorite.create!(user: @alice, favoritable: submissions(:url_low), created_at: 2.days.ago)
    Favorite.create!(user: @alice, favoritable: submissions(:ask_one), created_at: 1.day.ago)
    Favorite.create!(user: @bob, favoritable: submissions(:url_high))       # another user's
    Favorite.create!(user: @alice, favoritable: comments(:second))          # a comment
    get_as @bob, "/api/v1/users/#{@alice.id}/favorites/submissions"

    assert_response :ok
    assert_equal [ submissions(:ask_one).id, submissions(:url_low).id ], json.map { |s| s["id"] }
    assert_equal "bob", json.last["user"]["username"]
  end

  test "favorites/comments: most recently favorited first, each with its submission" do
    Favorite.create!(user: @alice, favoritable: comments(:second), created_at: 2.days.ago)
    Favorite.create!(user: @alice, favoritable: comments(:on_low), created_at: 1.day.ago)
    Favorite.create!(user: @bob, favoritable: comments(:first))             # another user's
    Favorite.create!(user: @alice, favoritable: submissions(:url_low))      # a submission
    get_as @bob, "/api/v1/users/#{@alice.id}/favorites/comments"

    assert_response :ok
    assert_equal [ comments(:on_low).id, comments(:second).id ], json.map { |c| c["id"] }
    assert_equal submissions(:url_high).id, json.last["submission"]["id"]
  end

  test "a user without submissions, comments or favorites gets empty lists" do
    lonely = User.create!(username: "lonely", provider: "github", uid: "99")
    %w[submissions comments favorites/submissions favorites/comments].each do |list|
      get_as @alice, "/api/v1/users/#{lonely.id}/#{list}"

      assert_response :ok
      assert_equal [], json, list
    end
  end

  # --- errors ---------------------------------------------------------------------------

  test "an unknown user is 404 in every endpoint" do
    [ "", "/submissions", "/comments", "/favorites/submissions", "/favorites/comments" ].each do |suffix|
      get_as @alice, "/api/v1/users/0#{suffix}"

      assert_response :not_found, suffix
      assert_equal({ "error" => "not_found", "message" => "User with id=0 not found" }, json)
    end
  end

  # On a GET, `params:` would go to the query string: RAW_POST_DATA (with its
  # length, or Rails does not parse it) is the way to send a real body.
  test "a malformed body does not turn the 404 into a 400" do
    body = '{"x":'
    get "/api/v1/users/0",
        headers: { "X-API-KEY" => @alice.api_key, "Content-Type" => "application/json" },
        env: { "RAW_POST_DATA" => body, "CONTENT_LENGTH" => body.bytesize.to_s }

    assert_response :not_found
  end

  test "requires an api-key" do
    [ "", "/submissions", "/comments", "/favorites/submissions", "/favorites/comments" ].each do |suffix|
      [ nil, "wrong" ].each do |key|
        get "/api/v1/users/#{@alice.id}#{suffix}", headers: { "X-API-KEY" => key }.compact

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
  end

  private

  def get_as(user, path)
    get path, headers: { "X-API-KEY" => user.api_key }
  end

  def json
    JSON.parse(response.body)
  end
end
