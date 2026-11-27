module Api
  module V1
    # API-12: favorite and unfavorite submissions and comments
    # (docs/api-design.md, §2.4).
    #
    #   POST   /api/v1/submissions/:submission_id/favorites  -> 201 { "favorited": true }
    #   DELETE /api/v1/submissions/:submission_id/favorites  -> 204
    #   POST   /api/v1/comments/:comment_id/favorites        -> 201 { "favorited": true }
    #   DELETE /api/v1/comments/:comment_id/favorites        -> 204
    #
    # Any item can be favorited, also your own (like the web). A user has at
    # most one favorite per item, so there is no favorite id. Unlike the web,
    # the API is strict: already a favorite -> 409, removing something that is
    # not a favorite -> 404.
    class FavoritesController < BaseController
      # Runs after authenticate_api_key!, so the order is 401 -> 404 -> 409.
      before_action :set_favoritable

      # POST .../favorites
      def create
        return already_favorited if @favoritable.favorites.exists?(user: current_user)

        @favoritable.favorites.create!(user: current_user)
        render json: { favorited: true }, status: :created
      rescue ActiveRecord::RecordNotUnique
        # Two simultaneous requests: the unique index rejects the second one.
        already_favorited
      end

      # DELETE .../favorites
      def destroy
        favorite = @favoritable.favorites.find_by(user: current_user)
        return render_error(404, "This #{kind} is not in your favorites") unless favorite

        favorite.destroy!
        head :no_content
      end

      private

      # The item comes from the URL: /submissions/:submission_id/favorites or
      # /comments/:comment_id/favorites. find raises RecordNotFound -> 404.
      # From the path and not from `params`, which also parses the body: with a
      # malformed JSON, `params` answers 400 before the 404 (docs/api-design.md
      # §1: 401 -> 404 -> 403 -> 400). The body is not read.
      def set_favoritable
        path = request.path_parameters
        @favoritable =
          if path[:submission_id]
            Submission.find(path[:submission_id])
          else
            Comment.find(path[:comment_id])
          end
      end

      def already_favorited
        render_error(409, "This #{kind} is already in your favorites")
      end

      # "submission" or "comment", for the error messages.
      def kind
        @favoritable.model_name.human.downcase
      end
    end
  end
end
