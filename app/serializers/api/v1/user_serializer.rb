module Api
  module V1
    # JSON representation of a user profile (see docs/api-design.md §3).
    # API-14 (GET /users/:id); reused by API-15 and API-16, which answer with
    # the updated profile.
    #
    # - The api-key is NEVER included.
    # - The email is only included when the viewer (the api-key user) is the
    #   user themself.
    # - avatar_url and banner_url are absolute URLs, so `base_url` (the
    #   request's scheme + host) is needed: the attached image if there is one,
    #   otherwise the default image, like the profile page of the web.
    class UserSerializer
      def initialize(user, viewer:, base_url:)
        @user = user
        @viewer = viewer
        @base_url = base_url
      end

      def as_json(*)
        u = @user
        json = {
          id: u.id,
          username: u.username,
          about: u.about,
          karma: u.karma,
          avatar_url: image_url(:avatar),
          banner_url: image_url(:banner),
          created_at: u.created_at.utc.iso8601
        }
        json[:email] = u.email if @viewer == u
        json
      end

      private

      def image_url(name)
        attachment = @user.public_send(name)
        if attachment.attached?
          Rails.application.routes.url_helpers.rails_blob_url(attachment, host: @base_url)
        else
          ActionController::Base.helpers.image_url(User::DEFAULT_IMAGES.fetch(name), host: @base_url)
        end
      end
    end
  end
end
