module Api
  module V1
    # API-07: reply to a comment, at any depth (docs/api-design.md, §2.2).
    class RepliesController < BaseController
      # POST /api/v1/comments/:comment_id/replies  { "body": "..." }
      #
      # The reply hangs under the parent comment and inherits its submission.
      # 201 with the new comment; 404 if the parent does not exist; 422 if the
      # body is missing or blank.
      def create
        parent = Comment.find(params[:comment_id])
        reply = parent.replies.create!(
          reply_params.merge(user: current_user, submission: parent.submission)
        )
        render json: CommentSerializer.new(reply), status: :created
      end

      private

      # Only the text: the author comes from the api-key; the parent and the
      # submission, from the URL. Not `require`, which would answer 400 (not 422)
      # to a blank body.
      def reply_params
        params.permit(:body)
      end
    end
  end
end
