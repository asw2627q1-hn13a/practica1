module CommentsHelper
  # COM-05: where a comment's "parent" link points. If the comment is a reply,
  # it goes to the comment it replies to; if it is a direct (top-level) comment,
  # it goes to the submission it belongs to. Works at any depth.
  def comment_parent_path(comment)
    if comment.parent_id
      comment_path(comment.parent_id)
    else
      submission_path(comment.submission_id)
    end
  end
end
