module Api
  module V1
    # API-11: vote and unvote submissions and comments (docs/api-design.md, §2.3).
    #
    #   POST   /api/v1/submissions/:submission_id/votes  -> 201 { "points": n }
    #   DELETE /api/v1/submissions/:submission_id/votes  -> 200 { "points": n }
    #   POST   /api/v1/comments/:comment_id/votes        -> 201 { "points": n }
    #   DELETE /api/v1/comments/:comment_id/votes        -> 200 { "points": n }
    #
    # A user has at most one vote per item, so the item and the api-key identify
    # the vote: there is no vote id. Unlike the web (which silently ignores a
    # repeated or own vote), the API is strict so a client knows whether the
    # action had any effect: own content -> 403, already voted -> 409,
    # unvoting something not voted -> 404.
    class VotesController < BaseController
      # Runs after authenticate_api_key!, so the order is 401 -> 404 -> 403 -> 409.
      before_action :set_votable

      # POST .../votes
      def create
        return render_error(403, "You cannot vote your own #{kind}") if @votable.user_id == current_user.id
        return already_voted if @votable.votes.exists?(user: current_user)

        # Both changes or none: a vote without its point (or the opposite) would
        # leave the points out of sync with the votes.
        Vote.transaction do
          @votable.votes.create!(user: current_user)
          @votable.increment!(:points)
        end
        render json: { points: @votable.points }, status: :created
      rescue ActiveRecord::RecordNotUnique
        # Two simultaneous votes: the unique index on votes rejects the second one.
        already_voted
      end

      # DELETE .../votes
      def destroy
        vote = @votable.votes.find_by(user: current_user)
        return render_error(404, "You have not voted this #{kind}") unless vote

        Vote.transaction do
          vote.destroy!
          @votable.decrement!(:points)
        end
        render json: { points: @votable.points }
      end

      private

      # The voted item comes from the URL: /submissions/:submission_id/votes or
      # /comments/:comment_id/votes. find raises RecordNotFound -> 404.
      # From the path and not from `params`, which also parses the body: with a
      # malformed JSON, `params` answers 400 before the 404 or the 403
      # (docs/api-design.md §1: 401 -> 404 -> 403 -> 400). The body is not read.
      def set_votable
        path = request.path_parameters
        @votable =
          if path[:submission_id]
            Submission.find(path[:submission_id])
          else
            Comment.find(path[:comment_id])
          end
      end

      def already_voted
        render_error(409, "You have already voted this #{kind}")
      end

      # "submission" or "comment", for the error messages.
      def kind
        @votable.model_name.human.downcase
      end
    end
  end
end
