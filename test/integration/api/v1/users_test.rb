require "test_helper"

# API-14/API-17: user profile, activity, hidden submissions and upvoted items.
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

  test "hidden submissions are private and ordered by when hidden" do
    Hide.create!(user: @alice, submission: submissions(:url_high), created_at: 2.days.ago)
    Hide.create!(user: @alice, submission: submissions(:ask_one), created_at: 1.day.ago)
    Hide.create!(user: @bob, submission: submissions(:url_low))

    get_as @alice, "/api/v1/users/#{@alice.id}/hidden"

    assert_response :ok
    assert_equal [ submissions(:ask_one).id, submissions(:url_high).id ], json.map { |s| s["id"] }

    get_as @bob, "/api/v1/users/#{@alice.id}/hidden"
    assert_response :forbidden
  end

  test "upvoted submissions are private and ordered by when voted" do
    newer_submission = Submission.create!(
      user: @bob,
      title: "Another submission",
      url: "https://example.net/another",
      submission_type: "url"
    )
    Vote.create!(user: @alice, votable: submissions(:url_low), created_at: 2.days.ago)
    Vote.create!(user: @alice, votable: newer_submission, created_at: 1.day.ago)
    Vote.create!(user: @alice, votable: comments(:second))
    Vote.create!(user: @bob, votable: submissions(:url_high))

    get_as @alice, "/api/v1/users/#{@alice.id}/upvoted/submissions"

    assert_response :ok
    assert_equal [ newer_submission.id, submissions(:url_low).id ], json.map { |s| s["id"] }
    assert_equal "bob", json.first["user"]["username"]
  end

  test "upvoted comments are private, ordered by vote time and include their submission" do
    Vote.create!(user: @alice, votable: comments(:second), created_at: 2.days.ago)
    Vote.create!(user: @alice, votable: comments(:reply_to_first), created_at: 1.day.ago)
    Vote.create!(user: @alice, votable: submissions(:url_low))
    Vote.create!(user: @bob, votable: comments(:first))

    get_as @alice, "/api/v1/users/#{@alice.id}/upvoted/comments"

    assert_response :ok
    assert_equal [ comments(:reply_to_first).id, comments(:second).id ], json.map { |c| c["id"] }
    assert_equal submissions(:url_high).id, json.first["submission"]["id"]
    assert json.all? { |comment| comment["user"]["id"] == @bob.id }
  end

  test "unhide and unvote remove items from the private activity lists" do
    post "/api/v1/submissions/#{submissions(:url_low).id}/hidden", headers: auth(@alice)
    post "/api/v1/submissions/#{submissions(:url_low).id}/votes", headers: auth(@alice)
    post "/api/v1/comments/#{comments(:second).id}/votes", headers: auth(@alice)

    get_as @alice, "/api/v1/users/#{@alice.id}/hidden"
    assert_includes json.map { |submission| submission["id"] }, submissions(:url_low).id

    get_as @alice, "/api/v1/users/#{@alice.id}/upvoted/submissions"
    assert_includes json.map { |submission| submission["id"] }, submissions(:url_low).id

    get_as @alice, "/api/v1/users/#{@alice.id}/upvoted/comments"
    assert_includes json.map { |comment| comment["id"] }, comments(:second).id

    delete "/api/v1/submissions/#{submissions(:url_low).id}/hidden", headers: auth(@alice)
    delete "/api/v1/submissions/#{submissions(:url_low).id}/votes", headers: auth(@alice)
    delete "/api/v1/comments/#{comments(:second).id}/votes", headers: auth(@alice)

    get_as @alice, "/api/v1/users/#{@alice.id}/hidden"
    assert_empty json

    get_as @alice, "/api/v1/users/#{@alice.id}/upvoted/submissions"
    assert_empty json

    get_as @alice, "/api/v1/users/#{@alice.id}/upvoted/comments"
    assert_empty json
  end

  test "a user without submissions, comments or favorites gets empty lists" do
    lonely = User.create!(username: "lonely", provider: "github", uid: "99")
    %w[submissions comments favorites/submissions favorites/comments].each do |list|
      get_as @alice, "/api/v1/users/#{lonely.id}/#{list}"

      assert_response :ok
      assert_equal [], json, list
    end
  end

  test "an owner without hidden or upvoted items gets empty lists" do
    lonely = User.create!(username: "lonely", provider: "github", uid: "100")
    %w[hidden upvoted/submissions upvoted/comments].each do |list|
      get_as lonely, "/api/v1/users/#{lonely.id}/#{list}"

      assert_response :ok
      assert_equal [], json, list
    end
  end

  # --- errors ---------------------------------------------------------------------------

  test "an unknown user is 404 in every endpoint" do
    [
      "", "/submissions", "/comments", "/favorites/submissions", "/favorites/comments",
      "/hidden", "/upvoted/submissions", "/upvoted/comments"
    ].each do |suffix|
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
    [
      "", "/submissions", "/comments", "/favorites/submissions", "/favorites/comments",
      "/hidden", "/upvoted/submissions", "/upvoted/comments"
    ].each do |suffix|
      [ nil, "wrong" ].each do |key|
        get "/api/v1/users/#{@alice.id}#{suffix}", headers: { "X-API-KEY" => key }.compact

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
  end

  test "a different api-key cannot access hidden or upvoted lists" do
    %w[hidden upvoted/submissions upvoted/comments].each do |list|
      get_as @bob, "/api/v1/users/#{@alice.id}/#{list}"

      assert_response :forbidden, list
      assert_equal "forbidden", json["error"], list
    end
  end

  private

  def auth(user)
    { "X-API-KEY" => user.api_key }
  end

  def get_as(user, path)
    get path, headers: auth(user)
  end

  def json
    JSON.parse(response.body)
  end
end
