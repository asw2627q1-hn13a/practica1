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
    assert_redirected_to @submission
  end

  test "an empty comment is rejected" do
    log_in_as(users(:alice))
    assert_no_difference("Comment.count") do
      post submission_comments_url(@submission), params: { comment: { body: "" } }
    end
    assert_response :unprocessable_content
  end
end
