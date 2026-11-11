class SubmissionsController < ApplicationController
  before_action :require_login, only: %i[ new create edit update destroy delete
                                          upvote unvote favorite unfavorite hide unhide hidden ]
  before_action :set_submission, only: %i[ show edit update destroy delete
                                           upvote unvote favorite unfavorite hide unhide ]
  before_action :require_owner, only: %i[ edit update destroy delete ]

  # GET / (news) and /submissions
  # SUB-01: url submissions ranked by points. ACT-06: hide the user's hidden ones.
  def index
    @submissions = visible(Submission.of_type("url").ranked).includes(:user)
  end

  # GET /newest (SUB-02b): all submissions, most recent first.
  def newest
    @submissions = visible(Submission.by_time).includes(:user)
    render :index
  end

  # GET /ask (SUB-02b): only ask submissions, most recent first.
  def ask
    @submissions = visible(Submission.of_type("ask").by_time).includes(:user)
    render :index
  end

  # GET /hidden (ACT-06): the logged-in user's hidden submissions, to unhide.
  def hidden
    @submissions = current_user.hidden_submissions.ranked.includes(:user)
  end

  # GET /submissions/1
  def show
    @comment = Comment.new
    @comments = @submission.comments.chronological.includes(:user)
  end

  # GET /submissions/new
  def new
    @submission = Submission.new
  end

  # GET /submissions/1/edit (ACT-01, owner only)
  def edit
  end

  # POST /submissions (SUB-02a): create a submission from the submit form.
  def create
    @submission = Submission.new(submission_params)
    @submission.user = current_user
    @submission.assign_type_from_url

    # SUB-04: if a submission with this url already exists, show it instead of
    # creating a duplicate (even if the title differs). Ask submissions, which
    # have no url, are never affected by this check.
    if @submission.url.present?
      existing = Submission.find_by(url: @submission.url)
      if existing
        redirect_to existing, notice: "This URL has already been submitted."
        return
      end
    end

    respond_to do |format|
      if @submission.save
        format.html { redirect_to newest_path, notice: "Submission was successfully created." }
        format.json { render :show, status: :created, location: @submission }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @submission.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /submissions/1 (ACT-01, owner only)
  def update
    respond_to do |format|
      if @submission.update(submission_params)
        format.html { redirect_to @submission, notice: "Submission was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @submission }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @submission.errors, status: :unprocessable_content }
      end
    end
  end

  # GET /submissions/1/delete (ACT-02): no-JS delete confirmation page.
  def delete
  end

  # DELETE /submissions/1 (ACT-02, owner only). Comments go with it (dependent).
  def destroy
    @submission.destroy!
    redirect_to root_path, notice: "Submission deleted.", status: :see_other
  end

  # POST /submissions/1/upvote (ACT-03): vote another user's submission once.
  def upvote
    unless @submission.owned_by?(current_user)
      if @submission.votes.create(user: current_user).persisted?
        @submission.increment!(:points)
      end
    end
    redirect_back fallback_location: @submission
  end

  # POST /submissions/1/unvote (ACT-03)
  def unvote
    vote = @submission.votes.find_by(user: current_user)
    if vote
      vote.destroy
      @submission.decrement!(:points)
    end
    redirect_back fallback_location: @submission
  end

  # POST /submissions/1/favorite (ACT-05)
  def favorite
    @submission.favorites.find_or_create_by(user: current_user)
    redirect_back fallback_location: @submission
  end

  # POST /submissions/1/unfavorite (ACT-05)
  def unfavorite
    @submission.favorites.where(user: current_user).destroy_all
    redirect_back fallback_location: @submission
  end

  # POST /submissions/1/hide (ACT-06)
  def hide
    @submission.hides.find_or_create_by(user: current_user)
    redirect_back fallback_location: root_path
  end

  # POST /submissions/1/unhide (ACT-06)
  def unhide
    @submission.hides.where(user: current_user).destroy_all
    redirect_back fallback_location: hidden_path
  end

  private

  def set_submission
    @submission = Submission.find(params.expect(:id))
  end

  # ACT-01/02: only the author may edit or delete, even via a direct URL.
  def require_owner
    unless @submission.owned_by?(current_user)
      redirect_to @submission, alert: "You can only modify your own submissions."
    end
  end

  # ACT-06: drop the current user's hidden submissions from a listing.
  def visible(scope)
    return scope unless current_user

    scope.where.not(id: current_user.hides.select(:submission_id))
  end

  def submission_params
    params.expect(submission: [ :title, :url, :text ])
  end
end
