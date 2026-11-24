require "test_helper"

class CommentsHelperTest < ActionView::TestCase
  # COM-05: the "parent" link target, independent of any view's HTML.
  test "a direct comment's parent path is its submission" do
    comment = comments(:first) # top-level comment (parent_id is nil)
    assert_nil comment.parent_id
    assert_equal submission_path(comment.submission_id), comment_parent_path(comment)
  end

  test "a reply's parent path is the comment it answers" do
    reply = comments(:reply_to_first) # replies to "first"
    assert_equal comments(:first).id, reply.parent_id
    assert_equal comment_path(reply.parent_id), comment_parent_path(reply)
  end
end
