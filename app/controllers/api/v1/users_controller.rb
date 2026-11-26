module Api
  module V1
    # API-10: threads of a user.
    # API-14: profile of any user and their submissions, comments and favorites.
    # API-16: upload (multipart/form-data) and reset of the avatar and banner.
    # The other user actions (API-15, API-17) will be added here by their stories.
    #
    # All of them are public, like the profile on the web: any valid api-key can
    # see any user. An unknown user is 404 and an empty list is 200 [].
    class UsersController < BaseController
      # API-16: the images of a profile (the `kind` of DELETE .../images/:kind
      # and the parts of PUT .../images).
      IMAGE_KINDS = %i[avatar banner].freeze

      # GET /api/v1/users/:id
      #
      # The profile (docs/api-design.md §3). The email only for the api-key
      # user's own profile; the api-key never.
      def show
        render json: UserSerializer.new(find_user, viewer: current_user, base_url: request.base_url)
      end

      # GET /api/v1/users/:id/submissions — newest first, like /submissions?id=
      # on the web. Submissions hidden by the api-key user are not excluded:
      # hiding only affects the general listings (GET /submissions).
      def submissions
        submissions = find_user.submissions.by_time.order(id: :desc).includes(:user)
        render json: SubmissionSerializer.list(submissions)
      end

      # GET /api/v1/users/:id/comments — newest first, flat, each with its
      # `submission` ({id, title}).
      def comments
        comments = find_user.comments.by_recent.order(id: :desc).includes(:user, :submission)
        render json: CommentSerializer.flat(comments)
      end

      # GET /api/v1/users/:id/favorites/submissions — most recently favorited first.
      def favorite_submissions
        render json: SubmissionSerializer.list(favorited(find_user, "Submission", :user))
      end

      # GET /api/v1/users/:id/favorites/comments — most recently favorited first,
      # each with its `submission`.
      def favorite_comments
        render json: CommentSerializer.flat(favorited(find_user, "Comment", %i[user submission]))
      end

      # GET /api/v1/users/:id/threads
      #
      # The user's comments (newest first), each with the replies it has
      # received in `replies` (direct replies, chronological). Public, like
      # /threads?id= on the web; the api-key user is just one case. An empty
      # list is 200 []; an unknown user is 404.
      def threads
        user = User.find(params[:id])
        comments = user.comments.by_recent.order(id: :desc).includes(:user, :submission).to_a
        replies_by_parent = Comment.where(parent_id: comments.map(&:id))
                                   .chronological.order(:id).includes(:user)
                                   .group_by(&:parent_id)

        render json: comments.map { |comment|
          CommentSerializer.thread(comment, replies_by_parent.fetch(comment.id, []))
        }
      end

      # PUT /api/v1/users/:id/images (multipart/form-data)
      #
      # API-16: uploads a new avatar, a new banner or both (parts `avatar` and
      # `banner`, as files). Only the owner of the profile (403 for the rest).
      # Check order: 401 -> 404 -> 403 -> 400 -> 422 (docs/api-design.md §1).
      #
      # - Neither part sent: 400.
      # - A part that is not a file, or a file that is not a PNG/JPEG/GIF/WebP
      #   image or is over 5 MB: 422, with the errors by field in `details`.
      #   The validation is the one of the web (User#images_must_be_valid, by
      #   content and not by name). It is all or nothing: if one of the two
      #   files is invalid, neither is saved.
      # - The new images replace the old ones (Active Storage, in the external
      #   object storage in production). 200 with the updated profile.
      def update_images
        user = find_user
        authorize_owner!(user)

        uploads = IMAGE_KINDS.index_with { |kind| params[kind] }
                             .reject { |_kind, value| value.nil? || value == "" }
        return render_error(400, "Missing required parameter: avatar or banner") if uploads.empty?

        not_files = uploads.reject { |_kind, value| value.respond_to?(:tempfile) }
        if not_files.any?
          return render_error(422, "Validation failed",
                              details: not_files.keys.index_with { [ "must be a file (multipart/form-data)" ] })
        end

        user.assign_attributes(uploads)
        return render_validation_errors(user) unless user.save

        render json: UserSerializer.new(user.reload, viewer: current_user, base_url: request.base_url)
      end

      # DELETE /api/v1/users/:id/images/:kind
      #
      # API-16: `kind` is `avatar` or `banner`; the image goes back to the
      # default one, like the "delete" checkbox of the web (USR-06). Only the
      # owner. Another `kind` is 404 (it is part of the URI, so it is checked
      # with the user and before the 403). 200 with the updated profile.
      def destroy_image
        user = find_user
        kind = request.path_parameters[:kind].to_s
        unless IMAGE_KINDS.map(&:to_s).include?(kind)
          # -> 404 "Image with id=<kind> not found" (handler of BaseController)
          raise ActiveRecord::RecordNotFound.new("Image not found", "Image", "kind", kind)
        end

        authorize_owner!(user)
        user.reset_to_default(kind)

        render json: UserSerializer.new(user.reload, viewer: current_user, base_url: request.base_url)
      end

      private

      # The id comes from the URL path and not from `params`, which also parses
      # the body: a malformed JSON must not turn the 404 into a 400
      # (docs/api-design.md §1: 401 -> 404 -> 403 -> 400).
      def find_user
        User.find(request.path_parameters[:id])
      end

      # The items of `type` ("Submission" or "Comment") that `user` has marked
      # as favorite, most recently favorited first (same date: highest id
      # first), like the favorites pages of the web (USR-07).
      def favorited(user, type, preload)
        user.favorites.where(favoritable_type: type)
            .order(created_at: :desc, id: :desc)
            .includes(favoritable: preload)
            .map(&:favoritable)
      end
    end
  end
end