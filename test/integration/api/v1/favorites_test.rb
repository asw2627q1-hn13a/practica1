require "test_helper"

# API-12: POST / DELETE /api/v1/submissions/:id/favorites and /api/v1/comments/:id/favorites.
#
# Fixtures: url_high and comment "first" are alice's; url_low and comment
# "second" are bob's. There are no favorites in the fixtures.
class Api::V1::FavoritesTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @bobs_submission = submissions(:url_low)
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

  test "favoriting requires an api-key" do
    assert_no_difference "Favorite.count" do
      post "/api/v1/submissions/#{@bobs_submission.id}/favorites"
    end
    assert_response :unauthorized
  end

  test "favoriting or unfavoriting a missing item is 404" do
    post "/api/v1/submissions/0/favorites", headers: auth(@alice)
    assert_response :not_found
    assert_equal "not_found", json["error"]

    delete "/api/v1/comments/0/favorites", headers: auth(@alice)
    assert_response :not_found
  end

  # --- submissions --------------------------------------------------------------

  test "favoriting a submission returns 201 and favorited true" do
    assert_difference "Favorite.count", 1 do
      post "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)
    end
    assert_response :created
    assert_equal({ "favorited" => true }, json)
    assert @bobs_submission.favorited_by?(@alice)
  end

  test "a user can favorite their own submission" do
    post "/api/v1/submissions/#{@alices_submission.id}/favorites", headers: auth(@alice)

    assert_response :created
    assert @alices_submission.favorited_by?(@alice)
  end

  test "the favorite belongs to the api-key user only" do
    post "/api/v1/submissions/#{@alices_submission.id}/favorites",
         params: { user_id: @alice.id }.to_json,
         headers: auth(@bob).merge("Content-Type" => "application/json")

    assert_response :created
    assert @alices_submission.favorited_by?(@bob)
    assert_not @alices_submission.favorited_by?(@alice)
  end

  test "favoriting the same submission twice is 409 and does not duplicate it" do
    post "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)

    assert_no_difference "Favorite.count" do
      post "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)
    end
    assert_response :conflict
    assert_equal "This submission is already in your favorites", json["message"]
  end

  test "unfavoriting a submission returns 204 with no body" do
    post "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)

    assert_difference "Favorite.count", -1 do
      delete "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)
    end
    assert_response :no_content
    assert_empty @response.body
    assert_not @bobs_submission.favorited_by?(@alice)
  end

  test "unfavoriting a submission that is not a favorite is 404" do
    delete "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)

    assert_response :not_found
    assert_equal "This submission is not in your favorites", json["message"]
  end

  test "unfavoriting only removes the api-key user's favorite" do
    # bob first, so "the first favorite of the item" is not alice's.
    post "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@bob)
    post "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)

    delete "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)

    assert_response :no_content
    assert_not @bobs_submission.favorited_by?(@alice)
    assert @bobs_submission.favorited_by?(@bob)
  end

  test "another user's favorite does not count as yours: 404 and it stays" do
    post "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@bob)

    delete "/api/v1/submissions/#{@bobs_submission.id}/favorites", headers: auth(@alice)

    assert_response :not_found
    assert @bobs_submission.favorited_by?(@bob)
  end

  # --- comments -------------------------------------------------------------------

  test "favoriting a comment returns 201 and favorited true" do
    assert_difference "Favorite.count", 1 do
      post "/api/v1/comments/#{@bobs_comment.id}/favorites", headers: auth(@alice)
    end
    assert_response :created
    assert_equal({ "favorited" => true }, json)
    assert @bobs_comment.favorited_by?(@alice)
  end

  test "a user can favorite their own comment" do
    post "/api/v1/comments/#{@alices_comment.id}/favorites", headers: auth(@alice)

    assert_response :created
  end

  test "favoriting the same comment twice is 409" do
    post "/api/v1/comments/#{@bobs_comment.id}/favorites", headers: auth(@alice)
    post "/api/v1/comments/#{@bobs_comment.id}/favorites", headers: auth(@alice)

    assert_response :conflict
    assert_equal "This comment is already in your favorites", json["message"]
  end

  test "unfavoriting a comment returns 204" do
    post "/api/v1/comments/#{@bobs_comment.id}/favorites", headers: auth(@alice)
    delete "/api/v1/comments/#{@bobs_comment.id}/favorites", headers: auth(@alice)

    assert_response :no_content
    assert_not @bobs_comment.favorited_by?(@alice)
  end

  test "unfavoriting a comment that is not a favorite is 404" do
    delete "/api/v1/comments/#{@bobs_comment.id}/favorites", headers: auth(@alice)

    assert_response :not_found
    assert_equal "This comment is not in your favorites", json["message"]
  end
end
