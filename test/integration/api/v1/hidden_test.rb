require "test_helper"

# API-13: POST / DELETE /api/v1/submissions/:submission_id/hidden.
class Api::V1::HiddenTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @submission = submissions(:url_low)
  end

  test "hiding requires an api-key" do
    assert_no_difference "Hide.count" do
      post "/api/v1/submissions/#{@submission.id}/hidden"
    end

    assert_response :unauthorized
  end

  test "unhiding requires an api-key" do
    @submission.hides.create!(user: @alice)

    assert_no_difference "Hide.count" do
      delete "/api/v1/submissions/#{@submission.id}/hidden"
    end

    assert_response :unauthorized
  end

  test "hiding or unhiding a missing submission is 404" do
    post "/api/v1/submissions/0/hidden", headers: auth(@alice)
    assert_response :not_found

    delete "/api/v1/submissions/0/hidden", headers: auth(@alice)
    assert_response :not_found
  end

  test "hiding uses the api-key user and duplicate requests do not create another hide" do
    headers = auth(@alice).merge("Content-Type" => "application/json")
    body = { user_id: @bob.id }.to_json

    assert_difference "Hide.count", 1 do
      post "/api/v1/submissions/#{@submission.id}/hidden", params: body, headers: headers
    end
    assert_response :created
    assert_equal({ "hidden" => true }, JSON.parse(response.body))
    assert @submission.hides.exists?(user: @alice)
    assert_not @submission.hides.exists?(user: @bob)

    assert_no_difference "Hide.count" do
      post "/api/v1/submissions/#{@submission.id}/hidden", headers: auth(@alice)
    end
    assert_response :conflict
    assert_equal "This submission is already hidden", JSON.parse(response.body)["message"]
  end

  test "unhiding removes only the api-key user's hide" do
    @submission.hides.create!(user: @bob)

    assert_no_difference "Hide.count" do
      delete "/api/v1/submissions/#{@submission.id}/hidden", headers: auth(@alice)
    end
    assert_response :not_found
    assert @submission.hides.exists?(user: @bob)

    assert_difference "Hide.count", -1 do
      delete "/api/v1/submissions/#{@submission.id}/hidden", headers: auth(@bob)
    end
    assert_response :no_content
    assert_empty response.body

    get "/api/v1/submissions", params: { list: "newest" }, headers: auth(@bob)
    assert_response :success
    ids = JSON.parse(response.body).map { |submission| submission["id"] }
    assert_includes ids, @submission.id
  end

  test "hidden is only available for submissions, not comments" do
    post "/api/v1/comments/#{comments(:first).id}/hidden", headers: auth(@alice)

    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body)["error"]
  end

  private

  def auth(user)
    { "X-API-KEY" => user.api_key }
  end
end
