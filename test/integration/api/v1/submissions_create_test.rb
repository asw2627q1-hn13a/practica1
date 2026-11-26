require "test_helper"

# API-04: POST /api/v1/submissions
class Api::V1::SubmissionsCreateTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @auth = { "X-API-KEY" => @alice.api_key }
  end

  test "requires an api-key" do
    assert_no_difference("Submission.count") do
      post "/api/v1/submissions", params: { title: "x", url: "https://a.example.com" }, as: :json
    end
    assert_response :unauthorized
  end

  test "creates a url submission (201) owned by the api-key user" do
    assert_difference("Submission.count", 1) do
      post "/api/v1/submissions",
        params: { title: "A brand new link", url: "https://new.example.com" }, headers: @auth, as: :json
    end
    assert_response :created
    body = JSON.parse(@response.body)
    assert_equal "url", body["submission_type"]
    assert_equal "A brand new link", body["title"]
    assert_equal @alice.username, body["user"]["username"]
  end

  test "creates an ask submission when url is blank (201)" do
    assert_difference("Submission.count", 1) do
      post "/api/v1/submissions", params: { title: "Ask: a question?", text: "details" }, headers: @auth, as: :json
    end
    assert_response :created
    assert_equal "ask", JSON.parse(@response.body)["submission_type"]
  end

  test "an empty title answers 422" do
    assert_no_difference("Submission.count") do
      post "/api/v1/submissions", params: { title: "", url: "https://x.example.com" }, headers: @auth, as: :json
    end
    assert_response :unprocessable_entity
    assert_equal "unprocessable_entity", JSON.parse(@response.body)["error"]
  end

  test "an invalid url answers 422" do
    assert_no_difference("Submission.count") do
      post "/api/v1/submissions", params: { title: "bad url", url: "not-a-url" }, headers: @auth, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "a duplicate url answers 409 with the existing id and creates nothing" do
    existing = submissions(:url_high)
    assert_no_difference("Submission.count") do
      post "/api/v1/submissions", params: { title: "different title, same url", url: existing.url }, headers: @auth, as: :json
    end
    assert_response :conflict
    body = JSON.parse(@response.body)
    assert_equal "conflict", body["error"]
    assert_equal existing.id, body.dig("details", "existing_submission_id")
  end

  test "the author comes from the api-key, not from a user_id in the body" do
    post "/api/v1/submissions",
      params: { title: "mine", url: "https://mine.example.com", user_id: users(:bob).id },
      headers: @auth, as: :json
    assert_response :created
    assert_equal @alice.id, Submission.find_by(title: "mine").user_id
  end
end
