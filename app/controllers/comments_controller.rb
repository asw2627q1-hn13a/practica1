class CommentsController < ApplicationController
  before_action :require_login

  # POST /submissions/:submission_id/comments
  # COM-01: add a comment to a submission (logged-in users only).
  def create
    @submission = Submission.find(params[:submission_id])
    @comment = @submission.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to @submission, notice: "Comment added."
    else
      # Re-render the submission page with the form errors (@comment holds them).
      @comments = @submission.comments.chronological.includes(:user)
      render "submissions/show", status: :unprocessable_content
    end
  end

  private

  def comment_params
    params.expect(comment: [ :body ])
  end
end
