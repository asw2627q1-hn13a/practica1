class CommentsController < ApplicationController
  # threads is public when filtered by a user id (USR-07: /threads?id=<user id>);
  # without id it shows the logged-in user's own threads and needs login.
  before_action :require_login, except: %i[ index threads ]
  before_action :require_login_unless_filtered, only: :threads
  before_action :set_submission, only: %i[ new create ]
  before_action :set_comment, only: %i[ edit update destroy delete
                                        upvote unvote favorite unfavorite ]
  before_action :require_owner, only: %i[ edit update destroy delete ]

  # GET /comments (LST-03): latest comments from everyone, newest first.
  def index
    @comments = Comment.by_recent.includes(:user, :submission)
  end

  # GET /threads (LST-02): a user's comments, each with the replies it has
  # received. USR-07: ?id=<user id> picks the user (404 if it doesn't exist);
  # without it, it is the logged-in user.
  def threads
    @threads_user = params[:id].present? ? User.find(params[:id]) : current_user
    @comments = @threads_user.comments.by_recent.includes(:user, :submission)
  end

  # GET /submissions/:submission_id/comments/new(?parent_id=)  (COM-02)
  def new
    @parent = @submission.comments.find(params[:parent_id]) if params[:parent_id].present?
    @comment = @submission.comments.build(parent: @parent)
  end

  # POST /submissions/:submission_id/comments  (COM-01 / COM-02)
  def create
    @comment = @submission.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to submission_path(@submission, anchor: "comment-#{@comment.id}"),
        notice: "Comment added."
    elsif @comment.parent_id
      @parent = @comment.parent
      render :new, status: :unprocessable_content
    else
      @comments = @submission.comments.chronological.includes(:user)
      render "submissions/show", status: :unprocessable_content
    end
  end

  # GET /comments/:id/edit (ACT-01, owner only)
  def edit
  end

  # PATCH/PUT /comments/:id (ACT-01, owner only)
  def update
    if @comment.update(edit_params)
      redirect_to submission_path(@comment.submission, anchor: "comment-#{@comment.id}"),
        notice: "Comment updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # GET /comments/:id/delete (ACT-02): no-JS delete confirmation page.
  def delete
  end

  # DELETE /comments/:id (ACT-02, owner only). Replies go with it (dependent).
  def destroy
    submission = @comment.submission
    @comment.destroy!
    redirect_to submission_path(submission), notice: "Comment deleted.", status: :see_other
  end

  # POST /comments/:id/upvote (ACT-04): vote another user's comment once.
  def upvote
    unless @comment.owned_by?(current_user)
      if @comment.votes.create(user: current_user).persisted?
        @comment.increment!(:points)
      end
    end
    redirect_back fallback_location: @comment.submission
  end

  # POST /comments/:id/unvote (ACT-04)
  def unvote
    vote = @comment.votes.find_by(user: current_user)
    if vote
      vote.destroy
      @comment.decrement!(:points)
    end
    redirect_back fallback_location: @comment.submission
  end

  # POST /comments/:id/favorite (ACT-05)
  def favorite
    @comment.favorites.find_or_create_by(user: current_user)
    redirect_back fallback_location: @comment.submission
  end

  # POST /comments/:id/unfavorite (ACT-05)
  def unfavorite
    @comment.favorites.where(user: current_user).destroy_all
    redirect_back fallback_location: @comment.submission
  end

  private

  def require_login_unless_filtered
    require_login unless params[:id].present?
  end

  def set_submission
    @submission = Submission.find(params[:submission_id])
  end

  def set_comment
    @comment = Comment.find(params[:id])
  end

  # ACT-01/02: only the author may edit or delete, even via a direct URL.
  def require_owner
    unless @comment.owned_by?(current_user)
      redirect_to @comment.submission, alert: "You can only modify your own comments."
    end
  end

  def comment_params
    params.expect(comment: [ :body, :parent_id ])
  end

  def edit_params
    params.expect(comment: [ :body ])
  end
end