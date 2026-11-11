class UsersController < ApplicationController
  before_action :require_login, only: %i[ edit update upvoted_submissions upvoted_comments ]
  before_action :set_user, except: %i[ upvoted_submissions upvoted_comments ]
  before_action :require_owner, only: %i[ edit update ]

  # GET /users/1 (USR-03)
  def show
  end

  # GET /users/1/submissions (USR-07): the user's submissions, newest first.
  def submissions
    @submissions = @user.submissions.by_time.includes(:user)
  end

  # GET /users/1/favorite_submissions (USR-07): most recently favorited first.
  def favorite_submissions
    @submissions = @user.favorites.where(favoritable_type: "Submission")
                        .order(created_at: :desc, id: :desc)
                        .includes(favoritable: :user).map(&:favoritable)
  end

  # GET /users/1/favorite_comments (USR-07): most recently favorited first.
  def favorite_comments
    @comments = @user.favorites.where(favoritable_type: "Comment")
                      .order(created_at: :desc, id: :desc)
                      .includes(favoritable: [ :user, :submission ]).map(&:favoritable)
  end

  # GET /upvoted (USR-08): submissions the logged-in user has voted, most recent
  # first. No user id in the URL, so only your own votes can be seen.
  def upvoted_submissions
    @submissions = current_user.votes.where(votable_type: "Submission")
                                .order(created_at: :desc, id: :desc)
                                .includes(votable: :user).map(&:votable)
  end

  # GET /upvoted/comments (USR-08): comments the logged-in user has voted.
  def upvoted_comments
    @comments = current_user.votes.where(votable_type: "Comment")
                            .order(created_at: :desc, id: :desc)
                            .includes(votable: [ :user, :submission ]).map(&:votable)
  end

  # GET /users/1/edit (USR-04)
  def edit
  end

  # PATCH/PUT /users/1 (USR-04, USR-06)
  def update
    if @user.update(user_params)
      reset_images_if_requested
      redirect_to @user, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  # un usuari només pot editar el seu propi perfil
  def require_owner
    unless @user == current_user
      redirect_to user_path(@user), alert: "You can only edit your own profile."
    end
  end

  # un usuari només pot editar els camps "email", "about", "avatar" i "banner"
  def user_params
    params.expect(user: [ :about, :email, :avatar, :banner ])
  end

  # USR-06: the "delete" checkboxes go back to the default image.
  # A new file uploaded in the same request takes precedence over "delete".
  def reset_images_if_requested
    %i[avatar banner].each do |name|
      next if params.dig(:user, name).present?

      @user.reset_to_default(name) if params["remove_#{name}"] == "1"
    end
  end
end