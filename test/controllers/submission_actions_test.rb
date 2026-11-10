require "test_helper"

class SubmissionActionsTest < ActionDispatch::IntegrationTest
  # ACT-03 -------------------------------------------------------------------

  test "voting another user's submission adds a point" do
    log_in_as(users(:alice))
    submission = submissions(:url_low) # bob's
    assert_difference -> { submission.reload.points }, 1 do
      assert_difference("Vote.count", 1) do
        post upvote_submission_url(submission)
      end
    end
  end

  test "cannot vote your own submission" do
    log_in_as(users(:alice))
    assert_no_difference("Vote.count") do
      post upvote_submission_url(submissions(:url_high)) # alice's
    end
  end

  test "cannot vote the same submission twice" do
    log_in_as(users(:alice))
    submission = submissions(:url_low)
    post upvote_submission_url(submission)
    assert_no_difference("Vote.count") do
      post upvote_submission_url(submission)
    end
  end

  test "unvoting removes the point" do
    log_in_as(users(:alice))
    submission = submissions(:url_low)
    post upvote_submission_url(submission)
    assert_difference -> { submission.reload.points }, -1 do
      post unvote_submission_url(submission)
    end
  end

  # ACT-05 -------------------------------------------------------------------

  test "favorite and unfavorite a submission" do
    log_in_as(users(:alice))
    submission = submissions(:url_low)
    assert_difference("Favorite.count", 1) { post favorite_submission_url(submission) }
    assert_difference("Favorite.count", -1) { post unfavorite_submission_url(submission) }
  end

  # ACT-06 -------------------------------------------------------------------

  test "hiding a submission removes it from news and shows it on the hidden page" do
    log_in_as(users(:alice))
    submission = submissions(:url_high)
    post hide_submission_url(submission)

    get news_url
    assert_not @response.body.include?(submission.title)

    get hidden_url
    assert_includes @response.body, submission.title
  end

  # ACT-01 / ACT-02 ----------------------------------------------------------

  test "cannot edit another user's submission, even via direct URL" do
    log_in_as(users(:alice))
    get edit_submission_url(submissions(:url_low)) # bob's
    assert_redirected_to submissions(:url_low)
  end

  test "owner can delete own submission (and its comments go with it)" do
    log_in_as(users(:alice))
    assert_difference("Submission.count", -1) do
      delete submission_url(submissions(:url_high)) # alice's
    end
    assert_redirected_to root_path
  end

  test "cannot delete another user's submission" do
    log_in_as(users(:alice))
    assert_no_difference("Submission.count") do
      delete submission_url(submissions(:url_low)) # bob's
    end
  end

  test "actions require login" do
    post upvote_submission_url(submissions(:url_low))
    assert_redirected_to login_path
  end
end
