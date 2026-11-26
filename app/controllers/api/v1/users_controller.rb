module Api
  module V1
    # API-10: threads of a user.
    # API-14: profile of any user and their submissions, comments and favorites.
    # The other user actions (API-15..17) will be added here by their stories.
    #
    # All of them are public, like the profile on the web: any valid api-key can
    # see any user. An unknown user is 404 and an empty list is 200 [].
    class UsersController < BaseController
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

      # GET /api/v1/users/:id/hidden
      def hidden
        user = find_user
        authorize_owner!(user, message: "You can only see your own hidden submissions")

        hides = user.hides.includes(submission: :user).order(created_at: :desc, id: :desc)
        render json: SubmissionSerializer.list(hides.map(&:submission))
      end

      # GET /api/v1/users/:id/upvoted/submissions
      def upvoted_submissions
        user = find_user
        authorize_owner!(user, message: "You can only see your own upvoted submissions")

        render json: SubmissionSerializer.list(voted(user, "Submission", :user))
      end

      # GET /api/v1/users/:id/upvoted/comments
      def upvoted_comments
        user = find_user
        authorize_owner!(user, message: "You can only see your own upvoted comments")

        render json: CommentSerializer.flat(voted(user, "Comment", %i[user submission]))
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

      # The items the user voted for, most recently voted first.
      def voted(user, type, preload)
        user.votes.where(votable_type: type)
            .order(created_at: :desc, id: :desc)
            .includes(votable: preload)
            .map(&:votable)
      end
    end
  end
end
