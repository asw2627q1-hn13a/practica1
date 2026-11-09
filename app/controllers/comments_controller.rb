class CommentsController < ApplicationController
  before_action :require_login, except: :index
  before_action :set_submission, only: %i[ new create ]

  # GET /comments (LST-03): latest comments from everyone, newest first.
  def index
    @comments = Comment.by_recent.includes(:user, :submission)
  end

  # GET /threads (LST-02): the logged-in user's comments, each with the
  # replies it has received. Requires login (handled by before_action).
  def threads
    @comments = current_user.comments.by_recent.includes(:user, :submission)
  end

  # GET /submissions/:submission_id/comments/new(?parent_id=)
  # COM-02: reply form. With a parent_id it replies to that comment; without
  # one it is a plain top-level comment form.
  def new
    @parent = @submission.comments.find(params[:parent_id]) if params[:parent_id].present?
    @comment = @submission.comments.build(parent: @parent)
  end

  # POST /submissions/:submission_id/comments
  # COM-01 top-level comment, or COM-02 reply when comment[parent_id] is set.
  def create
    @comment = @submission.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to submission_path(@submission, anchor: "comment-#{@comment.id}"),
        notice: "Comment added."
    elsif @comment.parent_id
      # A reply failed validation: re-render the reply form with its errors.
      @parent = @comment.parent
      render :new, status: :unprocessable_content
    else
      # A top-level comment failed: re-render the submission page.
      @comments = @submission.comments.chronological.includes(:user)
      render "submissions/show", status: :unprocessable_content
    end
  end

  private

  def set_submission
    @submission = Submission.find(params[:submission_id])
  end

  def comment_params
    params.expect(comment: [ :body, :parent_id ])
  end
end
