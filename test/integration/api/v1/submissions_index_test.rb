require "test_helper"

# API-03: GET /api/v1/submissions (news / newest / ask + search).
class Api::V1::SubmissionsIndexTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @headers = { "X-API-KEY" => @alice.api_key }
  end

  def titles(response)
    JSON.parse(response.body).map { |s| s["title"] }
  end

  test "requires an api-key" do
    get "/api/v1/submissions"
    assert_response :unauthorized
    assert_equal "unauthorized", JSON.parse(@response.body)["error"]
  end

  test "news (default) lists only url submissions ranked by points" do
    get "/api/v1/submissions", headers: @headers
    assert_response :success
    t = titles(@response)
    assert_includes t, submissions(:url_high).title
    assert_includes t, submissions(:url_low).title
    assert_not_includes t, submissions(:ask_one).title
    # ranked: url_high (100 pts) before url_low (10 pts)
    assert_operator t.index(submissions(:url_high).title), :<, t.index(submissions(:url_low).title)
  end

  test "newest lists all submissions including ask" do
    get "/api/v1/submissions", params: { list: "newest" }, headers: @headers
    assert_response :success
    assert_includes titles(@response), submissions(:ask_one).title
  end

  test "ask lists only ask submissions" do
    get "/api/v1/submissions", params: { list: "ask" }, headers: @headers
    assert_response :success
    types = JSON.parse(@response.body).map { |s| s["submission_type"] }.uniq
    assert_equal ["ask"], types
  end

  test "an invalid list value answers 400" do
    get "/api/v1/submissions", params: { list: "foo" }, headers: @headers
    assert_response :bad_request
    assert_equal "bad_request", JSON.parse(@response.body)["error"]
  end

  test "search matches titles case-insensitively across all types" do
    get "/api/v1/submissions", params: { q: "ASK" }, headers: @headers
    assert_response :success
    assert_includes titles(@response), submissions(:ask_one).title
  end

  test "a search with no matches returns an empty array with 200" do
    get "/api/v1/submissions", params: { q: "zzzz-no-match" }, headers: @headers
    assert_response :success
    assert_equal [], JSON.parse(@response.body)
  end

  test "hidden submissions are excluded from all lists only for the api-key user" do
    hidden_url = submissions(:url_high)
    hidden_ask = submissions(:ask_one)
    @alice.hides.create!(submission: hidden_url)
    @alice.hides.create!(submission: hidden_ask)

    {
      "news" => [ hidden_url ],
      "newest" => [ hidden_url, hidden_ask ],
      "ask" => [ hidden_ask ]
    }.each do |list, hidden_submissions|
      get "/api/v1/submissions", params: { list: list }, headers: @headers

      assert_response :success
      ids = JSON.parse(response.body).map { |submission| submission["id"] }
      hidden_submissions.each do |submission|
        assert_not_includes ids, submission.id
      end
    end

    bob_headers = { "X-API-KEY" => users(:bob).api_key }
    {
      "news" => [ hidden_url ],
      "newest" => [ hidden_url, hidden_ask ],
      "ask" => [ hidden_ask ]
    }.each do |list, visible_submissions|
      get "/api/v1/submissions", params: { list: list }, headers: bob_headers

      assert_response :success
      ids = JSON.parse(response.body).map { |submission| submission["id"] }
      visible_submissions.each do |submission|
        assert_includes ids, submission.id
      end
    end
  end

  test "each submission includes the documented fields" do
    get "/api/v1/submissions", headers: @headers
    sub = JSON.parse(@response.body).find { |s| s["title"] == submissions(:url_high).title }
    %w[id title url domain text submission_type points comments_count user created_at updated_at].each do |field|
      assert sub.key?(field), "expected field #{field}"
    end
    assert_equal @alice.username, sub["user"]["username"]
  end
end
