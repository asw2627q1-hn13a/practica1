class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  # TEMPORARY current_user until USR-01 (external sign in) is merged.
  # As the team plan says, use a user from the seeds in the meantime.
  def current_user
    @current_user ||= User.first
  end
end
