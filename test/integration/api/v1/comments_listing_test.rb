require "test_helper"

# API-10: GET /api/v1/comments and GET /api/v1/users/:id/threads.
class Api::V1::CommentsListingTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @headers = { "X-API-KEY" => @alice.api_key }
    # Distinct times so the order is deterministic.
    comments(:first).update_columns(created_at: 4.hours.ago)
    comments(:second).update_columns(created_at: 3.hours.ago)
    comments(:reply_to_first).update_columns(created_at: 2.hours.ago)
    comments(:on_low).update_columns(created_at: 1.hour.ago)
  end

  def json
    JSON.parse(response.body)
  end

  # --- GET /comments -----------------------------------------------------------

  test "listing comments requires an api-key" do
    get "/api/v1/comments"
    assert_response :unauthorized
    assert_equal "unauthorized", json["error"]
  end

  test "lists the comments of all users, newest first, with the submission" do
    get "/api/v1/comments", headers: @headers

    assert_response :success
    assert_match %r{application/json}, response.media_type
    assert_equal [ comments(:on_low), comments(:reply_to_first), comments(:second), comments(:first) ].map(&:id),
                 json.map { |c| c["id"] }

    reply = json.find { |c| c["id"] == comments(:reply_to_first).id }
    assert_equal "A reply to the first comment", reply["body"]
    assert_equal({ "id" => @bob.id, "username" => "bob" }, reply["user"])
    assert_equal comments(:first).id, reply["parent_id"]
    assert_equal({ "id" => submissions(:url_high).id, "title" => submissions(:url_high).title }, reply["submission"])
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, reply["created_at"])
    assert_not reply.key?("replies"), "the listing is flat"
  end

  test "an empty comment listing is 200 with an empty array" do
    Comment.delete_all
    get "/api/v1/comments", headers: @headers

    assert_response :success
    assert_equal [], json
  end

  # --- GET /users/:id/threads ----------------------------------------------------

  test "threads requires an api-key" do
    get "/api/v1/users/#{@alice.id}/threads"
    assert_response :unauthorized
  end

  test "threads are the user's comments with the replies they received" do
    get "/api/v1/users/#{@alice.id}/threads", headers: @headers

    assert_response :success
    # alice wrote "first" and "on_low", newest first.
    assert_equal [ comments(:on_low).id, comments(:first).id ], json.map { |c| c["id"] }

    first = json.last
    assert_equal [ comments(:reply_to_first).id ], first["replies"].map { |r| r["id"] }
    assert_equal({ "id" => @bob.id, "username" => "bob" }, first["replies"].first["user"])
    assert_equal comments(:first).id, first["replies"].first["parent_id"]
    assert_equal submissions(:url_high).id, first["submission"]["id"]
    assert_equal [], json.first["replies"]
  end

  test "replies are in chronological order" do
    later = comments(:first).replies.create!(body: "later", user: @alice, submission: submissions(:url_high))
    later.update_columns(created_at: 1.minute.ago)

    get "/api/v1/users/#{@alice.id}/threads", headers: @headers

    first = json.find { |c| c["id"] == comments(:first).id }
    assert_equal [ comments(:reply_to_first).id, later.id ], first["replies"].map { |r| r["id"] }
  end

  test "threads are public: another user's api-key can read them" do
    get "/api/v1/users/#{@alice.id}/threads", headers: { "X-API-KEY" => @bob.api_key }

    assert_response :success
    assert_equal 2, json.size
  end

  test "a user without comments has an empty thread list" do
    Comment.where(user: @bob).delete_all
    get "/api/v1/users/#{@bob.id}/threads", headers: @headers

    assert_response :success
    assert_equal [], json
  end

  test "threads of a missing user is 404" do
    get "/api/v1/users/0/threads", headers: @headers

    assert_response :not_found
    assert_equal "not_found", json["error"]
  end
end