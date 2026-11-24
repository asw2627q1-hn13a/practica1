module Api
  module V1
    # API-03: list submissions (news / newest / ask) and search them by title.
    class SubmissionsController < BaseController
      LISTS = %w[news newest ask].freeze

      # GET /api/v1/submissions?list=news|newest|ask&q=word
      #
      # - list=news (default): url submissions ranked by points.
      # - list=newest: all submissions, most recent first.
      # - list=ask: only ask submissions, most recent first.
      # - q: case-insensitive title search. Without list it searches ALL
      #   submissions ranked by points (like the web /search); with list it
      #   filters that listing.
      # Submissions the api-key user has hidden never appear.
      def index
        list = params[:list].presence
        if list && !LISTS.include?(list)
          return render_error(400, "Invalid 'list' value: #{list}. Allowed: #{LISTS.join(', ')}.")
        end

        query = params[:q].to_s.strip
        scope =
          if list.nil? && query.present?
            Submission.search_by_title(query).ranked
          else
            base = list_scope(list)
            query.present? ? base.search_by_title(query) : base
          end

        scope = scope.where.not(id: current_user.hides.select(:submission_id))
        render json: SubmissionSerializer.list(scope.includes(:user))
      end

      private

      def list_scope(list)
        case list
        when "newest" then Submission.by_time
        when "ask"    then Submission.of_type("ask").by_time
        else               Submission.of_type("url").ranked # news (default)
        end
      end
    end
  end
end
