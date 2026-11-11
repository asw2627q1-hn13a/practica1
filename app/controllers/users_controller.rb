class UsersController < ApplicationController
  before_action :require_login, only: %i[ edit update ]
  before_action :set_user
  before_action :require_owner, only: %i[ edit update ]

  # GET /users/1 (USR-03)
  def show
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