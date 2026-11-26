require "test_helper"

# API-06: DELETE /api/v1/submissions/:id, delete your own submission.
#
# Fixtures: url_high (alice) has 3 comments: "first" (alice), "second" (bob) and
# "reply_to_first" (bob, a reply to "first"). url_low is bob's and has 1 comment.
class Api::V1::SubmissionsDestroyTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @submission = submissions(:url_high)
  end

  test "the owner deletes it: 204 without body" do
    assert_difference "Submission.count", -1 do
      delete_submission @submission
    end

    assert_response :no_content
    assert_empty response.body
    assert_not Submission.exists?(@submission.id)
  end

  test "deletes its comments and replies and what hangs from them" do
    first = comments(:first)
    @submission.votes.create!(user: @bob)
    @submission.favorites.create!(user: @bob)
    @submission.hides.create!(user: @bob)
    first.votes.create!(user: @bob)
    comments(:reply_to_first).favorites.create!(user: @alice)

    assert_difference -> { Comment.count } => -3, -> { Vote.count } => -2,
                      -> { Favorite.count } => -2, -> { Hide.count } => -1 do
      delete_submission @submission
    end
    assert_response :no_content
    assert_not Comment.exists?(first.id)
  end

  test "other submissions and their comments are not touched" do
    other = submissions(:url_low)
    delete_submission @submission

    assert Submission.exists?(other.id)
    assert_equal [ comments(:on_low) ], other.comments.to_a
  end

  test "after deleting it, it is 404 and it is not listed" do
    delete_submission @submission

    get "/api/v1/submissions/#{@submission.id}", headers: auth(@alice)
    assert_response :not_found
    get "/api/v1/submissions?list=newest", headers: auth(@alice)
    assert_not_includes JSON.parse(response.body).map { |s| s["id"] }, @submission.id

    delete_submission @submission
    assert_response :not_found
  end

  test "another user's api-key is 403 and nothing is deleted" do
    assert_no_difference [ "Submission.count", "Comment.count" ] do
      delete_submission @submission, user: @bob
    end

    assert_response :forbidden
    assert_equal({ "error" => "forbidden", "message" => "You can only modify your own submissions" },
                 JSON.parse(response.body))
  end

  test "a missing submission is 404" do
    assert_no_difference "Submission.count" do
      delete "/api/v1/submissions/0", headers: auth(@alice)
    end

    assert_response :not_found
    assert_equal({ "error" => "not_found", "message" => "Submission with id=0 not found" },
                 JSON.parse(response.body))
  end

  test "requires an api-key, even if the submission does not exist" do
    [ @submission.id, 0 ].each do |id|
      [ {}, { "X-API-KEY" => "wrong" } ].each do |headers|
        assert_no_difference "Submission.count" do
          delete "/api/v1/submissions/#{id}", headers: headers
        end

        assert_response :unauthorized
        assert_equal "unauthorized", JSON.parse(response.body)["error"]
      end
    end
  end

  private

  def auth(user)
    { "X-API-KEY" => user.api_key }
  end

  def delete_submission(submission, user: @alice)
    delete "/api/v1/submissions/#{submission.id}", headers: auth(user)
  end
end
