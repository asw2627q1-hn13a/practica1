require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "valid comment" do
    comment = Comment.new(body: "Nice", user: users(:alice), submission: submissions(:url_high))
    assert comment.valid?
  end

  test "body is required" do
    comment = Comment.new(user: users(:alice), submission: submissions(:url_high))
    assert_not comment.valid?
    assert_includes comment.errors[:body], "can't be blank"
  end

  test "requires a user and a submission" do
    assert_not Comment.new(body: "x").valid?
  end

  test "counter_cache keeps submission comments_count in sync" do
    submission = submissions(:url_low)
    assert_difference -> { submission.reload.comments_count }, 1 do
      submission.comments.create!(body: "hello", user: users(:alice))
    end
  end
end
