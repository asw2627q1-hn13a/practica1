require "test_helper"

class CommentActionsTest < ActionDispatch::IntegrationTest
  # ACT-04 -------------------------------------------------------------------

  test "voting another user's comment adds a point" do
    log_in_as(users(:alice))
    comment = comments(:second) # bob's
    assert_difference -> { comment.reload.points }, 1 do
      assert_difference("Vote.count", 1) { post upvote_comment_url(comment) }
    end
  end

  test "cannot vote your own comment" do
    log_in_as(users(:alice))
    assert_no_difference("Vote.count") do
      post upvote_comment_url(comments(:first)) # alice's
    end
  end

  test "unvoting a comment removes the point" do
    log_in_as(users(:alice))
    comment = comments(:second)
    post upvote_comment_url(comment)
    assert_difference -> { comment.reload.points }, -1 do
      post unvote_comment_url(comment)
    end
  end

  # ACT-05 -------------------------------------------------------------------

  test "favorite and unfavorite a comment" do
    log_in_as(users(:alice))
    comment = comments(:second)
    assert_difference("Favorite.count", 1) { post favorite_comment_url(comment) }
    assert_difference("Favorite.count", -1) { post unfavorite_comment_url(comment) }
  end

  # ACT-01 -------------------------------------------------------------------

  test "owner can update own comment" do
    log_in_as(users(:alice))
    comment = comments(:first) # alice's
    patch comment_url(comment), params: { comment: { body: "edited body" } }
    assert_equal "edited body", comment.reload.body
    assert_redirected_to submission_path(comment.submission, anchor: "comment-#{comment.id}")
  end

  test "cannot edit another user's comment, even via direct URL" do
    log_in_as(users(:alice))
    get edit_comment_url(comments(:second)) # bob's
    assert_redirected_to comments(:second).submission
  end

  # ACT-02 -------------------------------------------------------------------

  test "owner can delete own comment" do
    log_in_as(users(:alice))
    assert_difference("Comment.count", -1) do
      delete comment_url(comments(:on_low)) # alice's, no replies
    end
  end

  test "cannot delete another user's comment" do
    log_in_as(users(:alice))
    assert_no_difference("Comment.count") do
      delete comment_url(comments(:second)) # bob's
    end
  end

  test "comment actions require login" do
    post upvote_comment_url(comments(:second))
    assert_redirected_to login_path
  end
end
