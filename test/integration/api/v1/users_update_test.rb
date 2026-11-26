require "test_helper"

# API-15: PUT /api/v1/users/:id, edit your own profile (about and email).
#
# Fixtures: alice (alice@example.com) and bob (bob@example.com), both without
# about.
class Api::V1::UsersUpdateTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  # --- editing ----------------------------------------------------------------------

  test "the owner edits about and email: 200 with the updated profile, email included" do
    put_json @alice, { about: "I write Rails", email: "new@example.com" }

    assert_response :ok
    assert_match %r{application/json}, response.media_type
    @alice.reload
    assert_equal "I write Rails", @alice.about
    assert_equal "new@example.com", @alice.email
    assert_equal %w[id username about karma avatar_url banner_url created_at email].sort, json.keys.sort
    assert_equal "I write Rails", json["about"]
    assert_equal "new@example.com", json["email"]
    assert_not_includes response.body, @alice.api_key
  end

  test "only the fields sent change" do
    put_json @alice, { about: "Only about" }

    assert_response :ok
    @alice.reload
    assert_equal "Only about", @alice.about
    assert_equal "alice@example.com", @alice.email
  end

  test "a blank about or email is stored as null" do
    @alice.update_columns(about: "Old about")
    [ "", "   ", nil ].each do |blank|
      put_json @alice, { about: blank, email: blank }

      assert_response :ok
      @alice.reload
      assert_nil @alice.about
      assert_nil @alice.email
      assert_nil json["about"]
      assert_nil json["email"]
      @alice.update_columns(about: "Old about", email: "alice@example.com")
    end
  end

  test "fields that are not editable are ignored" do
    api_key = @alice.api_key
    put_json @alice, {
      about: "Edited", id: @bob.id, username: "hacker", api_key: "stolen", karma: 999,
      provider: "x", uid: "x", avatar_url: "https://evil.example/a.png", created_at: "2000-01-01T00:00:00Z"
    }

    assert_response :ok
    @alice.reload
    assert_equal "Edited", @alice.about
    assert_equal "alice", @alice.username
    assert_equal api_key, @alice.api_key
    assert_equal %w[github 1], [ @alice.provider, @alice.uid ]
    assert_equal @alice.id, json["id"]
    assert_equal 105, json["karma"]
    assert_match %r{/assets/default_avatar-}, json["avatar_url"]
  end

  test "a body without editable fields answers 200 and changes nothing" do
    assert_no_changes -> { @alice.reload.attributes } do
      put_json @alice, { username: "nobody" }
    end
    assert_response :ok
    assert_equal "alice", json["username"]
  end

  # --- validations --------------------------------------------------------------------

  test "an invalid email is 422 and nothing changes" do
    assert_no_changes -> { @alice.reload.attributes } do
      put_json @alice, { about: "Not saved", email: "not-an-email" }
    end
    assert_response :unprocessable_content
    assert_equal({ "error" => "unprocessable_entity", "message" => "Validation failed",
                   "details" => { "email" => [ "is invalid" ] } }, json)
  end

  test "a malformed JSON body on your own profile is 400 and nothing changes" do
    assert_no_changes -> { @alice.reload.attributes } do
      put_raw @alice.id, '{"about":', user: @alice
    end
    assert_response :bad_request
    assert_equal "bad_request", json["error"]
  end

  # --- who can edit it ------------------------------------------------------------------

  test "another user's profile is 403 and nothing changes" do
    assert_no_changes -> { @bob.reload.attributes } do
      put_json @bob, { about: "Hacked", email: "hacked@example.com" }, user: @alice
    end
    assert_response :forbidden
    assert_equal({ "error" => "forbidden", "message" => "You can only modify your own profile" }, json)
  end

  test "an unknown user is 404" do
    put_raw 0, { about: "Hi" }.to_json, user: @alice

    assert_response :not_found
    assert_equal({ "error" => "not_found", "message" => "User with id=0 not found" }, json)
  end

  test "with a malformed body the order is still 404 and then 403" do
    put_raw 0, '{"about":', user: @alice
    assert_response :not_found

    put_raw @bob.id, '{"about":', user: @alice
    assert_response :forbidden
  end

  test "requires an api-key, even if the user does not exist" do
    [ @alice.id, 0 ].each do |id|
      [ nil, "wrong" ].each do |key|
        put "/api/v1/users/#{id}", params: { about: "Hi" }.to_json,
            headers: { "Content-Type" => "application/json", "X-API-KEY" => key }.compact

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
    assert_nil @alice.reload.about
  end

  private

  def put_json(target, body, user: target)
    put_raw target.id, body.to_json, user: user
  end

  def put_raw(id, raw_body, user:)
    put "/api/v1/users/#{id}", params: raw_body,
        headers: { "Content-Type" => "application/json", "X-API-KEY" => user.api_key }
  end

  def json
    JSON.parse(response.body)
  end
end
