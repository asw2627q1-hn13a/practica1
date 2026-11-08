require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @submission = submissions(:url_high)
  end

  test "requires login to add a comment" do
    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: { comment: { body: "Hi" } }
    end
    assert_redirected_to login_path
  end

  test "a logged-in user can add a comment" do
    log_in_as(users(:alice))
    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission), params: { comment: { body: "Great post!" } }
    end
    comment = Comment.find_by(body: "Great post!")
    assert_equal users(:alice), comment.user
    assert_equal @submission, comment.submission
    assert_nil comment.parent_id
    assert_redirected_to submission_path(@submission, anchor: "comment-#{comment.id}")
  end

  test "an empty comment is rejected" do
    log_in_as(users(:alice))
    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: { comment: { body: "" } }
    end
    assert_response :unprocessable_content
  end

  # COM-02 -------------------------------------------------------------------

  test "requires login to open the reply form" do
    get new_submission_comment_url(@submission, parent_id: comments(:first))
    assert_redirected_to login_path
  end

  test "a logged-in user sees the reply form for a comment" do
    log_in_as(users(:alice))
    get new_submission_comment_url(@submission, parent_id: comments(:first))
    assert_response :success
  end

  test "a logged-in user can reply to a comment" do
    log_in_as(users(:bob))
    parent = comments(:first)
    assert_difference("Comment.count", 1) do
      post submission_comments_url(@submission),
        params: { comment: { body: "Nice reply", parent_id: parent.id } }
    end
    reply = Comment.find_by(body: "Nice reply")
    assert_equal parent, reply.parent
    assert_equal @submission, reply.submission
    assert_redirected_to submission_path(@submission, anchor: "comment-#{reply.id}")
  end

  test "a reply cannot cross submissions" do
    log_in_as(users(:alice))
    other_submission = submissions(:url_low)
    assert_no_difference("Comment.count") do
      post submission_comments_url(other_submission),
        params: { comment: { body: "cross", parent_id: comments(:first).id } }
    end
    assert_response :unprocessable_content
  end
end
