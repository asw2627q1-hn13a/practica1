class SubmissionsController < ApplicationController
  before_action :set_submission, only: %i[ show edit update destroy ]

  # GET / (news) and /submissions
  # SUB-01: show url submissions ranked by points (most relevant first).
  def index
    @submissions = Submission.of_type("url").ranked.includes(:user)
  end

  # GET /newest (SUB-02b): all submissions, most recent first.
  def newest
    @submissions = Submission.by_time.includes(:user)
    render :index
  end

  # GET /ask (SUB-02b): only ask submissions, most recent first.
  def ask
    @submissions = Submission.of_type("ask").by_time.includes(:user)
    render :index
  end

  # GET /submissions/1 or /submissions/1.json
  # COM-03 will expand this; COM-01 shows the add-comment form and the comments.
  def show
    @comment = Comment.new
    @comments = @submission.comments.chronological.includes(:user)
  end

  # GET /submissions/new
  def new
    @submission = Submission.new
  end

  # GET /submissions/1/edit
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
        # On success show the newest page with the new submission on top.
        format.html { redirect_to newest_path, notice: "Submission was successfully created." }
        format.json { render :show, status: :created, location: @submission }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @submission.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /submissions/1 or /submissions/1.json
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

  # DELETE /submissions/1 or /submissions/1.json
  def destroy
    @submission.destroy!

    respond_to do |format|
      format.html { redirect_to submissions_path, notice: "Submission was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_submission
      @submission = Submission.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def submission_params
      params.expect(submission: [ :title, :url, :text ])
    end
end
