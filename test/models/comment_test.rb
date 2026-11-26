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

  # API-09 -------------------------------------------------------------------

  test "destroying a comment deletes a very deep conversation under it" do
    submission = submissions(:ask_one)
    root = parent = submission.comments.create!(body: "root", user: users(:bob))
    300.times do |i|
      parent = submission.comments.create!(body: "level #{i}", user: users(:bob), parent: parent)
    end

    assert_difference -> { Comment.count } => -301, -> { submission.reload.comments_count } => -301 do
      root.destroy!
    end
  end

  test "destroying a comment deletes its replies at every level and nothing else" do
    submission = submissions(:ask_one)
    root = submission.comments.create!(body: "root", user: users(:bob))
    branch = submission.comments.create!(body: "branch", user: users(:bob), parent: root)
    leaf = submission.comments.create!(body: "leaf", user: users(:bob), parent: branch)
    sibling = submission.comments.create!(body: "sibling", user: users(:bob), parent: root)

    branch.destroy!

    assert_not Comment.exists?(branch.id)
    assert_not Comment.exists?(leaf.id)
    assert Comment.exists?(root.id)
    assert Comment.exists?(sibling.id)
  end

  test "destroying a comment deletes its replies even if they have a lower id" do
    parent = comments(:first)
    reply = comments(:reply_to_first)
    reply.update_columns(id: parent.id - 1) if reply.id > parent.id

    assert_difference "Comment.count", -2 do
      parent.reload.destroy!
    end
  end
end
