require "test_helper"

class SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @submission = submissions(:url_high)
  end

  test "should get index" do
    get submissions_url
    assert_response :success
  end

  test "news shows only url submissions ranked by points" do
    get root_url
    assert_response :success
    # Highest-points url submission appears before the lower one.
    assert_match(/A high ranked url submission.*A low ranked url submission/m, response.body)
    # Ask submissions are not shown on news.
    assert_no_match(/Ask HN about something/, response.body)
  end

  test "should get new" do
    get new_submission_url
    assert_response :success
  end

  test "should create submission" do
    assert_difference("Submission.count") do
      post submissions_url, params: { submission: { points: @submission.points, submission_type: @submission.submission_type, text: @submission.text, title: @submission.title, url: @submission.url, user_id: @submission.user_id } }
    end

    assert_redirected_to submission_url(Submission.last)
  end

  test "should show submission" do
    get submission_url(@submission)
    assert_response :success
  end

  test "should get edit" do
    get edit_submission_url(@submission)
    assert_response :success
  end

  test "should update submission" do
    patch submission_url(@submission), params: { submission: { points: @submission.points, submission_type: @submission.submission_type, text: @submission.text, title: @submission.title, url: @submission.url, user_id: @submission.user_id } }
    assert_redirected_to submission_url(@submission)
  end

  test "should destroy submission" do
    assert_difference("Submission.count", -1) do
      delete submission_url(@submission)
    end

    assert_redirected_to submissions_url
  end
end
