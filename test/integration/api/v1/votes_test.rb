require "test_helper"

# API-11: POST / DELETE /api/v1/submissions/:id/votes and /api/v1/comments/:id/votes.
#
# Fixtures: url_high and comment "first" are alice's; url_low and comment
# "second" are bob's. There are no votes in the fixtures.
class Api::V1::VotesTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @bobs_submission = submissions(:url_low)     # 10 points
    @alices_submission = submissions(:url_high)
    @bobs_comment = comments(:second)
    @alices_comment = comments(:first)
  end

  def auth(user)
    { "X-API-KEY" => user.api_key }
  end

  def json
    JSON.parse(@response.body)
  end

  # --- authentication and missing items --------------------------------------

  test "voting requires an api-key" do
    assert_no_difference "Vote.count" do
      post "/api/v1/submissions/#{@bobs_submission.id}/votes"
    end
    assert_response :unauthorized
  end

  test "voting a missing submission or comment is 404" do
    post "/api/v1/submissions/0/votes", headers: auth(@alice)
    assert_response :not_found
    assert_equal "not_found", json["error"]

    post "/api/v1/comments/0/votes", headers: auth(@alice)
    assert_response :not_found
  end

  # --- submissions --------------------------------------------------------------

  test "voting another user's submission adds a point and returns the points" do
    assert_difference "Vote.count", 1 do
      post "/api/v1/submissions/#{@bobs_submission.id}/votes", headers: auth(@alice)
    end
    assert_response :created
    assert_equal({ "points" => 11 }, json)
    assert_equal 11, @bobs_submission.reload.points
    assert @bobs_submission.voted_by?(@alice)
  end

  test "the voter comes from the api-key, never from the request body" do
    post "/api/v1/submissions/#{@bobs_submission.id}/votes",
         params: { user_id: @bob.id }.to_json,
         headers: auth(@alice).merge("Content-Type" => "application/json")

    assert_response :created
    assert @bobs_submission.voted_by?(@alice)
    assert_not @bobs_submission.voted_by?(@bob)
  end

  test "a user cannot vote their own submission: 403 and nothing changes" do
    assert_no_difference "Vote.count" do
      post "/api/v1/submissions/#{@alices_submission.id}/votes", headers: auth(@alice)
    end
    assert_response :forbidden
    assert_equal "You cannot vote your own submission", json["message"]
    assert_equal 100, @alices_submission.reload.points
  end

  test "a second vote on the same submission is 409 and does not add points" do
    post "/api/v1/submissions/#{@bobs_submission.id}/votes", headers: auth(@alice)

    assert_no_difference "Vote.count" do
      post "/api/v1/submissions/#{@bobs_submission.id}/votes", headers: auth(@alice)
    end
    assert_response :conflict
    assert_equal "conflict", json["error"]
    assert_equal 11, @bobs_submission.reload.points
  end

  test "unvoting a submission removes the vote and the point" do
    post "/api/v1/submissions/#{@bobs_submission.id}/votes", headers: auth(@alice)

    assert_difference "Vote.count", -1 do
      delete "/api/v1/submissions/#{@bobs_submission.id}/votes", headers: auth(@alice)
    end
    assert_response :ok
    assert_equal({ "points" => 10 }, json)
    assert_equal 10, @bobs_submission.reload.points
  end

  test "unvoting a submission you have not voted is 404 and does not change points" do
    delete "/api/v1/submissions/#{@bobs_submission.id}/votes", headers: auth(@alice)

    assert_response :not_found
    assert_equal "You have not voted this submission", json["message"]
    assert_equal 10, @bobs_submission.reload.points
  end

  test "a vote changes the order of the news listing" do
    # Same points: after alice's vote, bob's submission must go first.
    @alices_submission.update_column(:points, 100)
    @bobs_submission.update_column(:points, 100)

    post "/api/v1/submissions/#{@bobs_submission.id}/votes", headers: auth(@alice)
    get "/api/v1/submissions", headers: auth(@alice)

    ids = json.map { |s| s["id"] }
    assert_operator ids.index(@bobs_submission.id), :<, ids.index(@alices_submission.id)
    assert_equal 101, json.find { |s| s["id"] == @bobs_submission.id }["points"]
  end

  # --- comments -------------------------------------------------------------------

  test "voting another user's comment adds a point and returns the points" do
    assert_difference "Vote.count", 1 do
      post "/api/v1/comments/#{@bobs_comment.id}/votes", headers: auth(@alice)
    end
    assert_response :created
    assert_equal({ "points" => 1 }, json)
    assert @bobs_comment.reload.voted_by?(@alice)
  end

  test "a user cannot vote their own comment" do
    post "/api/v1/comments/#{@alices_comment.id}/votes", headers: auth(@alice)

    assert_response :forbidden
    assert_equal "You cannot vote your own comment", json["message"]
    assert_equal 0, @alices_comment.reload.points
  end

  test "a second vote on the same comment is 409" do
    post "/api/v1/comments/#{@bobs_comment.id}/votes", headers: auth(@alice)
    post "/api/v1/comments/#{@bobs_comment.id}/votes", headers: auth(@alice)

    assert_response :conflict
    assert_equal 1, @bobs_comment.reload.points
  end

  test "unvoting a comment removes the vote and the point" do
    post "/api/v1/comments/#{@bobs_comment.id}/votes", headers: auth(@alice)
    delete "/api/v1/comments/#{@bobs_comment.id}/votes", headers: auth(@alice)

    assert_response :ok
    assert_equal({ "points" => 0 }, json)
    assert_not @bobs_comment.reload.voted_by?(@alice)
  end

  test "unvoting a comment you have not voted is 404" do
    delete "/api/v1/comments/#{@bobs_comment.id}/votes", headers: auth(@alice)

    assert_response :not_found
    assert_equal "You have not voted this comment", json["message"]
  end
end
