module Api
  module V1
    # API-03: list submissions (news / newest / ask) and search them by title.
    # API-05: get a submission with its comment tree.
    # API-06: edit and delete your own submissions.
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

      # GET /api/v1/submissions/:id
      #
      # The submission plus `comments`: its complete comment tree, oldest first
      # at every level (same date: lowest id first). 404 if it does not exist. A
      # submission hidden by the api-key user is shown too: hiding only affects
      # the listings.
      def show
        submission = find_submission
        comments = submission.comments.chronological.order(:id).includes(:user)
        body = SubmissionSerializer.new(submission).as_json
                                   .merge(comments: CommentTreeSerializer.new(comments).as_json)

        # Not `render json: body`: it fails (500) from 50 levels of replies on,
        # because Rails allows at most 100 levels of nested JSON.
        render json: JSON.generate(body, max_nesting: 0)
      end

      # PUT /api/v1/submissions/:id  { "title": "...", "url": "...", "text": "..." }
      #
      # Only the owner. Partial update: only the fields sent change and any
      # other field is ignored. Same rules as creating one: a blank title or an
      # invalid url is 422 and the type follows the url ("url" with one, "ask"
      # without). 200 with the updated submission.
      def update
        submission = find_submission
        authorize_owner!(submission)
        submission.assign_attributes(submission_params)
        submission.assign_type_from_url
        submission.save!

        render json: SubmissionSerializer.new(submission)
      end

      private

      # The id comes from the URL path and not from `params`, which also reads
      # the body: with a malformed JSON, `params` answers 400 before the 404 or
      # the 403 (docs/api-design.md §1: 401 -> 404 -> 403 -> 400).
      def find_submission
        Submission.find(request.path_parameters[:id])
      end

      # The editable fields; the rest of the body is ignored. Not `require`: a
      # blank title must be a 422 of the validations, not a 400. A blank url
      # is stored as nil, like the url of an ask submission.
      def submission_params
        attrs = params.permit(:title, :url, :text)
        attrs[:url] = attrs[:url].presence if attrs.key?(:url)
        attrs
      end

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
