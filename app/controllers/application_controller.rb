class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  private

  def current_user
    if session[:user_id] && !@current_user
      @current_user = User.find_by(id: session[:user_id])
    end
    @current_user
  end

  def require_login
    if current_user
      return
    end
    if request.get?
      session[:return_to] = request.fullpath
    end
    redirect_to login_path, alert: "Cal iniciar sessió"
  end
end
