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

  # COM-02 -------------------------------------------------------------------

  test "a reply links to its parent and appears among the parent's replies" do
    parent = comments(:first)
    reply = comments(:reply_to_first)
    assert_equal parent, reply.parent
    assert_includes parent.replies, reply
  end

  test "roots scope returns only top-level comments" do
    assert_includes Comment.roots, comments(:first)
    assert_not_includes Comment.roots, comments(:reply_to_first)
  end

  test "a reply can nest at any depth" do
    submission = submissions(:url_high)
    level1 = submission.comments.create!(body: "l1", user: users(:alice))
    level2 = submission.comments.create!(body: "l2", user: users(:bob), parent: level1)
    level3 = submission.comments.create!(body: "l3", user: users(:alice), parent: level2)
    assert_equal level2, level3.parent
    assert_equal level1, level3.parent.parent
  end

  test "a reply must belong to the same submission as its parent" do
    reply = submissions(:url_low).comments.build(
      body: "cross", user: users(:alice), parent: comments(:first)
    )
    assert_not reply.valid?
    assert_includes reply.errors[:parent], "must belong to the same submission"
  end

  test "destroying a comment destroys its replies" do
    parent = comments(:first)
    assert_difference("Comment.count", -2) do
      parent.destroy
    end
  end
end
