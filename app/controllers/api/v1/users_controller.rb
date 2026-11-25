module Api
  module V1
    # API-10: threads of a user. The other user actions (API-14..17) will be
    # added here by their stories.
    class UsersController < BaseController
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
          CommentSerializer.with_replies(comment, replies_by_parent.fetch(comment.id, []))
            .merge(submission: CommentSerializer.submission_ref(comment))
        }
      end
    end
  end
end