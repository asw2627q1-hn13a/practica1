require "test_helper"

# API-09: DELETE /api/v1/comments/:id, delete your own comment.
#
# Fixtures: url_high (alice) has 3 comments: "first" (alice), "second" (bob) and
# "reply_to_first" (bob, a reply to "first"). url_low is bob's and has 1 comment.
class Api::V1::CommentsDestroyTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @submission = submissions(:url_high)
    @comment = comments(:first) # alice's, has a reply
    @reply = comments(:reply_to_first) # bob's, no replies
  end

  test "the owner deletes it: 204 without body" do
    assert_difference -> { Comment.count } => -1, -> { @submission.reload.comments_count } => -1 do
      delete_comment @reply, user: @bob
    end

    assert_response :no_content
    assert_empty response.body
    assert_not Comment.exists?(@reply.id)
    assert Comment.exists?(@comment.id), "the parent must not be deleted"
  end

  test "deletes its replies too, like the web" do
    assert_difference -> { Comment.count } => -2, -> { @submission.reload.comments_count } => -2 do
      delete_comment @comment
    end

    assert_response :no_content
    assert_not Comment.exists?(@comment.id)
    assert_not Comment.exists?(@reply.id)
  end

  test "deletes the votes and favorites of the comment and of its replies" do
    @comment.votes.create!(user: @bob)
    @reply.votes.create!(user: @alice)
    @reply.favorites.create!(user: @alice)

    assert_difference -> { Vote.count } => -2, -> { Favorite.count } => -1 do
      delete_comment @comment
    end
    assert_response :no_content
  end

  test "other comments and the submission are not touched" do
    delete_comment @comment

    assert Submission.exists?(@submission.id)
    assert Comment.exists?(comments(:second).id)
    assert Comment.exists?(comments(:on_low).id)
  end

  test "after deleting it, it is not listed and deleting it again is 404" do
    delete_comment @comment

    get "/api/v1/comments", headers: auth(@alice)
    ids = JSON.parse(response.body).map { |c| c["id"] }
    assert_not_includes ids, @comment.id
    assert_not_includes ids, @reply.id

    delete_comment @comment
    assert_response :not_found
  end

  test "another user's api-key is 403 and nothing is deleted" do
    assert_no_difference [ "Comment.count", "Vote.count", "Favorite.count" ] do
      delete_comment @comment, user: @bob
    end

    assert_response :forbidden
    assert_equal({ "error" => "forbidden", "message" => "You can only modify your own comments" },
                 JSON.parse(response.body))
  end

  test "a missing comment is 404" do
    assert_no_difference "Comment.count" do
      delete "/api/v1/comments/0", headers: auth(@alice)
    end

    assert_response :not_found
    assert_equal({ "error" => "not_found", "message" => "Comment with id=0 not found" },
                 JSON.parse(response.body))
  end

  test "requires an api-key, even if the comment does not exist" do
    [ @comment.id, 0 ].each do |id|
      [ {}, { "X-API-KEY" => "wrong" } ].each do |headers|
        assert_no_difference "Comment.count" do
          delete "/api/v1/comments/#{id}", headers: headers
        end

        assert_response :unauthorized
        assert_equal "unauthorized", JSON.parse(response.body)["error"]
      end
    end
  end

  private

  def auth(user)
    { "X-API-KEY" => user.api_key }
  end

  def delete_comment(comment, user: @alice)
    delete "/api/v1/comments/#{comment.id}", headers: auth(user)
  end
end
