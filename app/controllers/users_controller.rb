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

  # PATCH/PUT /users/1 (USR-04)
  def update
    if @user.update(user_params)
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

  # un usuari només pot editar els camps "email" i "about"
  def user_params
    params.expect(user: [ :about, :email ])
  end
end