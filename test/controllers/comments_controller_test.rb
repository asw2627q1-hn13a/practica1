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

  # LST-03 -------------------------------------------------------------------

  test "comments page lists everyone's comments without login" do
    get comments_url
    assert_response :success
    assert_includes @response.body, comments(:first).body
    assert_includes @response.body, comments(:on_low).body
  end

  test "comments page shows nested replies, vote actions and the submission link" do
    log_in_as(users(:bob))
    get comments_url
    assert_response :success
    # the root comment and its nested reply both appear in the thread
    assert_includes @response.body, comments(:first).body
    assert_includes @response.body, comments(:reply_to_first).body
    # a link back to the submission the thread belongs to
    assert_select "a[href=?]", submission_path(submissions(:url_high))
    # vote action is available on another user's comment (bob does not own "first")
    assert_select "form[action=?]", upvote_comment_path(comments(:first))
  end

  # LST-02 -------------------------------------------------------------------

  test "threads page requires login" do
    get threads_url
    assert_redirected_to login_path
  end

  test "threads page shows the user's comments and the replies they received" do
    log_in_as(users(:alice))
    get threads_url
    assert_response :success
    # alice's own comments
    assert_includes @response.body, comments(:first).body
    assert_includes @response.body, comments(:on_low).body
    # a reply alice received, shown beneath her comment
    assert_includes @response.body, comments(:reply_to_first).body
    # another user's unrelated top-level comment is not in alice's threads
    assert_not @response.body.include?(comments(:second).body)
  end

  # COM-04 -------------------------------------------------------------------

  test "a comment has its own public page with its subtree and a link to the submission" do
    get comment_url(comments(:first))
    assert_response :success
    # the comment itself
    assert_includes @response.body, comments(:first).body
    # and a reply from its subtree
    assert_includes @response.body, comments(:reply_to_first).body
    # a link back to the submission it belongs to
    assert_select "a[href=?]", submission_path(@submission)
  end

  test "a comment page shows only its own subtree, not other comments" do
    get comment_url(comments(:second))
    assert_response :success
    assert_includes @response.body, comments(:second).body
    # reply_to_first hangs under "first", so it is not on "second"'s page
    assert_not @response.body.include?(comments(:reply_to_first).body)
  end

  # COM-05 -------------------------------------------------------------------

  test "a direct comment's parent link points to its submission" do
    get submission_url(@submission)
    assert_response :success
    # "first" is a top-level comment on @submission -> parent goes to the submission
    assert_select "#comment-#{comments(:first).id} > .comment-meta > a[href=?]",
      submission_path(@submission), text: "parent"
  end

  test "a reply's parent link points to the comment it answers" do
    get submission_url(@submission)
    assert_response :success
    # "reply_to_first" replies to "first" -> parent goes to that comment's page
    assert_select "#comment-#{comments(:reply_to_first).id} > .comment-meta > a[href=?]",
      comment_path(comments(:first)), text: "parent"
  end

  test "the threads page shows parent links for a comment and its reply" do
    get threads_url(id: users(:alice).id)
    assert_response :success
    # alice's top-level comment -> parent goes to the submission
    assert_select "#comment-#{comments(:first).id} > .comment-meta > a[href=?]",
      submission_path(submissions(:url_high)), text: "parent"
    # the reply shown beneath it -> parent goes to the comment it answers
    assert_select "#comment-#{comments(:reply_to_first).id} > .comment-meta > a[href=?]",
      comment_path(comments(:first)), text: "parent"
  end

  test "a reply's own page links its parent to the comment it answers" do
    get comment_url(comments(:reply_to_first))
    assert_response :success
    assert_select "#comment-#{comments(:reply_to_first).id} > .comment-meta > a[href=?]",
      comment_path(comments(:first)), text: "parent"
  end

  test "a flat comment listing shows the parent link" do
    # favorite_comments renders comments/_listed; favorite a reply so its parent
    # points to the comment it answers.
    Favorite.create!(user: users(:alice), favoritable: comments(:reply_to_first))
    get favorite_comments_user_url(users(:alice))
    assert_response :success
    assert_select "#comment-#{comments(:reply_to_first).id} > .comment-meta > a[href=?]",
      comment_path(comments(:first)), text: "parent"
  end
end
