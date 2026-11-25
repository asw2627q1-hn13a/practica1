require "test_helper"

# API-07: POST /api/v1/submissions/:id/comments and /api/v1/comments/:id/replies.
#
# Fixtures: url_high (alice) has 3 comments: "first" (alice), "second" (bob) and
# "reply_to_first" (bob, a reply to "first"). url_low is bob's and has 1 comment.
class Api::V1::CommentsCreateTest < ActionDispatch::IntegrationTest
  # Requests that carry no text: all of them are the same 422.
  BLANK_BODIES = [ {}, { body: nil }, { body: "" }, { body: "   " } ].freeze

  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @submission = submissions(:url_low)
    @root = comments(:first)
    @nested = comments(:reply_to_first)
  end

  # --- comments on a submission ------------------------------------------------

  test "commenting a submission answers 201 with the new comment" do
    assert_difference -> { @submission.comments.count } => 1,
                      -> { @submission.reload.comments_count } => 1 do
      post_json comments_path(@submission), { body: "Great post" }, user: @alice
    end

    assert_response :created
    assert_match %r{application/json}, response.media_type
    assert_equal expected_json(Comment.find(json["id"])), json
    assert_equal "Great post", json["body"]
    assert_equal 0, json["points"]
    assert_equal({ "id" => @alice.id, "username" => "alice" }, json["user"])
    assert_equal @submission.id, json["submission_id"]
    assert_nil json["parent_id"]
  end

  test "dates are ISO 8601 in UTC" do
    post_json comments_path(@submission), { body: "Great post" }, user: @alice

    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, json["created_at"])
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, json["updated_at"])
  end

  test "a comment ignores every field of the body except the text" do
    post_json comments_path(@submission),
              { body: "Hi", user_id: @bob.id, points: 99, parent_id: @root.id,
                submission_id: submissions(:url_high).id },
              user: @alice

    assert_response :created
    comment = Comment.find(json["id"])
    assert_equal @alice, comment.user
    assert_equal 0, comment.points
    assert_nil comment.parent
    assert_equal @submission, comment.submission
  end

  test "a comment without text is 422 and is not saved" do
    BLANK_BODIES.each do |body|
      assert_no_difference "Comment.count" do
        post_json comments_path(@submission), body, user: @alice
      end
      assert_blank_body_error
    end
    assert_equal 1, @submission.reload.comments_count
  end

  test "commenting a missing submission is 404, even without text" do
    [ { body: "Hi" }, {} ].each do |body|
      assert_no_difference "Comment.count" do
        post_json "/api/v1/submissions/0/comments", body, user: @alice
      end
      assert_response :not_found
      assert_equal "not_found", json["error"]
      assert_equal "Submission with id=0 not found", json["message"]
    end
  end

  test "commenting requires an api-key, even if the submission does not exist" do
    [ comments_path(@submission), "/api/v1/submissions/0/comments" ].each do |path|
      assert_no_difference "Comment.count" do
        post_json path, { body: "Hi" }
      end
      assert_response :unauthorized
      assert_equal "unauthorized", json["error"]
    end
  end

  test "a malformed JSON body is 400" do
    assert_no_difference "Comment.count" do
      post comments_path(@submission), params: '{"body":',
           headers: { "X-API-KEY" => @alice.api_key, "Content-Type" => "application/json" }
    end
    assert_response :bad_request
    assert_equal "bad_request", json["error"]
  end

  # --- replies to a comment ------------------------------------------------------

  test "replying to a comment links the reply to its parent and submission" do
    submission = @root.submission
    assert_difference -> { @root.replies.count } => 1,
                      -> { submission.reload.comments_count } => 1 do
      post_json replies_path(@root), { body: "I agree" }, user: @bob
    end

    assert_response :created
    assert_match %r{application/json}, response.media_type
    assert_equal expected_json(Comment.find(json["id"])), json
    assert_equal "I agree", json["body"]
    assert_equal({ "id" => @bob.id, "username" => "bob" }, json["user"])
    assert_equal @root.id, json["parent_id"]
    assert_equal submission.id, json["submission_id"]
  end

  test "a reply can be replied at any depth" do
    parent_id = @nested.id
    3.times do |i|
      post_json "/api/v1/comments/#{parent_id}/replies", { body: "level #{i}" }, user: @alice

      assert_response :created
      assert_equal parent_id, json["parent_id"]
      assert_equal @nested.submission_id, json["submission_id"]
      parent_id = json["id"]
    end
  end

  test "a reply ignores every field of the body except the text" do
    post_json replies_path(@root),
              { body: "Hi", user_id: @alice.id, points: 99, parent_id: @nested.id,
                submission_id: @submission.id },
              user: @bob

    assert_response :created
    reply = Comment.find(json["id"])
    assert_equal @bob, reply.user
    assert_equal 0, reply.points
    assert_equal @root, reply.parent
    assert_equal @root.submission, reply.submission
  end

  test "a reply without text is 422 and is not saved" do
    BLANK_BODIES.each do |body|
      assert_no_difference "Comment.count" do
        post_json replies_path(@root), body, user: @alice
      end
      assert_blank_body_error
    end
    assert_equal 3, @root.submission.reload.comments_count
  end

  test "replying to a missing comment is 404, even without text" do
    [ { body: "Hi" }, {} ].each do |body|
      assert_no_difference "Comment.count" do
        post_json "/api/v1/comments/0/replies", body, user: @alice
      end
      assert_response :not_found
      assert_equal "not_found", json["error"]
      assert_equal "Comment with id=0 not found", json["message"]
    end
  end

  test "replying requires an api-key, even if the comment does not exist" do
    [ replies_path(@root), "/api/v1/comments/0/replies" ].each do |path|
      assert_no_difference "Comment.count" do
        post_json path, { body: "Hi" }
      end
      assert_response :unauthorized
      assert_equal "unauthorized", json["error"]
    end
  end

  private

  def comments_path(submission)
    "/api/v1/submissions/#{submission.id}/comments"
  end

  def replies_path(comment)
    "/api/v1/comments/#{comment.id}/replies"
  end

  # POST with a JSON body; without `user`, no api-key is sent.
  def post_json(path, body, user: nil)
    headers = { "Content-Type" => "application/json" }
    headers["X-API-KEY"] = user.api_key if user
    post path, params: body.to_json, headers: headers
  end

  def json
    JSON.parse(response.body)
  end

  # The exact representation of docs/api-design.md §3: no more and no fewer keys.
  def expected_json(comment)
    {
      "id" => comment.id,
      "body" => comment.body,
      "points" => comment.points,
      "user" => { "id" => comment.user.id, "username" => comment.user.username },
      "submission_id" => comment.submission_id,
      "parent_id" => comment.parent_id,
      "created_at" => comment.created_at.utc.iso8601,
      "updated_at" => comment.updated_at.utc.iso8601
    }
  end

  def assert_blank_body_error
    assert_response :unprocessable_content
    assert_equal "unprocessable_entity", json["error"]
    assert_equal "Validation failed", json["message"]
    assert_equal({ "body" => [ "can't be blank" ] }, json["details"])
  end
end
