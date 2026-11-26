module Api
  module V1
    # API-07: add a comment to a submission (docs/api-design.md, §2.2).
    # Replies to a comment are created by RepliesController.
    # API-10: list the latest comments of all users.
    class CommentsController < BaseController
      # GET /api/v1/comments
      #
      # Flat list (no tree) of every user's comments, newest first, each with
      # its author, creation time, text and the submission it belongs to.
      # Empty list -> 200 [].
      def index
        comments = Comment.by_recent.order(id: :desc).includes(:user, :submission)
        render json: CommentSerializer.flat(comments)
      end

      # POST /api/v1/submissions/:submission_id/comments  { "body": "..." }
      #
      # 201 with the new comment; 404 if the submission does not exist; 422 if
      # the body is missing or blank. create! and find raise the exceptions that
      # BaseController turns into those errors.
      def create
        submission = Submission.find(params[:submission_id])
        comment = submission.comments.create!(comment_params.merge(user: current_user))
        render json: CommentSerializer.new(comment), status: :created
      end

      private

      # Only the text: the author comes from the api-key and the submission from
      # the URL. Not `require`, which would answer 400 (not 422) to a blank body.
      def comment_params
        params.permit(:body)
      end
    end
  end
end