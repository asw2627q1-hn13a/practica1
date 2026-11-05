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

  test "creates a url submission and redirects to newest" do
    assert_difference("Submission.count") do
      post submissions_url, params: { submission: { title: "A brand new link", url: "https://new.example.com" } }
    end
    created = Submission.find_by(title: "A brand new link")
    assert_equal "url", created.submission_type
    assert created.user.present?
    assert_redirected_to newest_path
  end

  test "creates an ask submission when url is blank" do
    assert_difference("Submission.count") do
      post submissions_url, params: { submission: { title: "Ask: a question?", url: "", text: "details" } }
    end
    assert_equal "ask", Submission.find_by(title: "Ask: a question?").submission_type
  end

  test "does not create a submission without a title" do
    assert_no_difference("Submission.count") do
      post submissions_url, params: { submission: { title: "", url: "https://x.example.com" } }
    end
    assert_response :unprocessable_content
  end

  test "newest page lists ask submissions too" do
    get newest_url
    assert_response :success
    assert_match(/Ask HN about something/, response.body)
  end

  test "ask page shows only ask submissions" do
    get ask_url
    assert_response :success
    assert_match(/Ask HN about something/, response.body)
    assert_no_match(/A high ranked url submission/, response.body)
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
