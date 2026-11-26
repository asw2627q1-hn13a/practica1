require "test_helper"

# API-09: PUT /api/v1/comments/:id, edit your own comment.
#
# Fixtures: url_high (alice) has 3 comments: "first" (alice), "second" (bob) and
# "reply_to_first" (bob, a reply to "first"). url_low is bob's and has 1 comment.
class Api::V1::CommentsUpdateTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @comment = comments(:first) # alice's, has a reply
    @reply = comments(:reply_to_first) # bob's
  end

  # --- editing -----------------------------------------------------------------

  test "the owner edits the text: 200 with the updated comment" do
    put_json @comment, { body: "Edited text" }

    assert_response :ok
    assert_match %r{application/json}, response.media_type
    @comment.reload
    assert_equal "Edited text", @comment.body
    assert_equal expected_json(@comment), json
    assert_not json.key?("replies")
    assert_not json.key?("submission")
  end

  test "editing changes updated_at but not created_at" do
    travel 1.minute do
      assert_changes -> { @comment.reload.updated_at } do
        assert_no_changes -> { @comment.reload.created_at } do
          put_json @comment, { body: "Edited text" }
        end
      end
    end
    assert_equal @comment.reload.updated_at.utc.iso8601, json["updated_at"]
  end

  test "a reply can be edited too and keeps its parent" do
    put_json @reply, { body: "Edited reply" }, user: @bob

    assert_response :ok
    @reply.reload
    assert_equal "Edited reply", @reply.body
    assert_equal @comment, @reply.parent
    assert_equal @comment.id, json["parent_id"]
  end

  test "fields that are not editable are ignored" do
    put_json @comment, {
      body: "Edited text", points: 99, user_id: @bob.id, parent_id: comments(:second).id,
      submission_id: submissions(:url_low).id, created_at: "2000-01-01T00:00:00Z"
    }

    assert_response :ok
    @comment.reload
    assert_equal "Edited text", @comment.body
    assert_equal 0, @comment.points
    assert_equal @alice, @comment.user
    assert_nil @comment.parent_id
    assert_equal submissions(:url_high), @comment.submission
    assert_not_equal 2000, @comment.created_at.year
  end

  test "a request body without the text answers 200 and changes nothing" do
    [ {}, { points: 99 } ].each do |body|
      assert_no_changes -> { @comment.reload.attributes } do
        put_json @comment, body
      end
      assert_response :ok
      assert_equal expected_json(@comment.reload), json
    end
  end

  # --- validations ---------------------------------------------------------------

  test "a blank text is 422 and nothing changes" do
    [ nil, "", "   " ].each do |text|
      assert_no_changes -> { @comment.reload.attributes } do
        put_json @comment, { body: text }
      end
      assert_response :unprocessable_content
      assert_equal({ "error" => "unprocessable_entity", "message" => "Validation failed",
                     "details" => { "body" => [ "can't be blank" ] } }, json)
    end
  end

  test "a malformed JSON body is 400 and nothing changes" do
    assert_no_changes -> { @comment.reload.attributes } do
      put_raw @comment.id, '{"body":', user: @alice
    end
    assert_response :bad_request
    assert_equal "bad_request", json["error"]
  end

  # --- who can edit it -------------------------------------------------------------

  test "another user's api-key is 403 and nothing changes" do
    assert_no_changes -> { @comment.reload.attributes } do
      put_json @comment, { body: "Hacked" }, user: @bob
    end
    assert_response :forbidden
    assert_equal({ "error" => "forbidden", "message" => "You can only modify your own comments" }, json)
  end

  test "a missing comment is 404" do
    put_raw 0, { body: "Hi" }.to_json, user: @alice

    assert_response :not_found
    assert_equal({ "error" => "not_found", "message" => "Comment with id=0 not found" }, json)
  end

  test "with a malformed body the order is still 404 and then 403" do
    put_raw 0, '{"body":', user: @alice
    assert_response :not_found

    put_raw @comment.id, '{"body":', user: @bob
    assert_response :forbidden
  end

  test "requires an api-key, even if the comment does not exist" do
    [ @comment.id, 0 ].each do |id|
      [ nil, "wrong" ].each do |key|
        put "/api/v1/comments/#{id}", params: { body: "Hi" }.to_json,
            headers: { "Content-Type" => "application/json", "X-API-KEY" => key }.compact

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
    assert_equal "A first comment on the high submission", @comment.reload.body
  end

  private

  def put_json(comment, body, user: @alice)
    put_raw comment.id, body.to_json, user: user
  end

  def put_raw(id, raw_body, user:)
    put "/api/v1/comments/#{id}", params: raw_body,
        headers: { "Content-Type" => "application/json", "X-API-KEY" => user.api_key }
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
end
