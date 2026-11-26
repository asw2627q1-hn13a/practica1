module Api
  module V1
    # API-07: add a comment to a submission (docs/api-design.md, §2.2).
    # Replies to a comment are created by RepliesController.
    # API-08: get a comment with its complete subtree.
    # API-10: list the latest comments of all users.
    # API-09: edit and delete your own comments.
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

      # GET /api/v1/comments/:id
      #
      # The comment plus `replies`: its complete subtree (only its descendants,
      # not its parent or siblings), oldest first at every level (same date:
      # lowest id first). The root also has `submission` ({ id, title }) and
      # `parent_id` (nil for a direct comment). 404 if it does not exist.
      #
      # It loads all the comments of the submission in one query and keeps the
      # subtree in Ruby, so the number of queries does not grow with the replies.
      def show
        comment = Comment.includes(:submission).find(request.path_parameters[:id])
        comments = Comment.where(submission_id: comment.submission_id)
                          .chronological.order(:id).includes(:user).to_a
        tree = CommentTreeSerializer.new(subtree(comment, comments)).as_json.first
        body = tree.merge(submission: CommentSerializer.submission_ref(comment))

        # Not `render json: body`: it fails (500) from 50 levels of replies on,
        # because Rails allows at most 100 levels of nested JSON.
        render json: JSON.generate(body, max_nesting: 0)
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

      # PUT /api/v1/comments/:id  { "body": "..." }
      #
      # Only the author. Changes only the text: any other field of the request
      # body is ignored, and a request body without `body` answers 200 without
      # changes. A `body` that is null, empty or only spaces is 422. 200 with
      # the updated comment (plain, without `replies`).
      def update
        comment = find_comment
        authorize_owner!(comment)
        comment.update!(comment_params)

        render json: CommentSerializer.new(comment)
      end

      # DELETE /api/v1/comments/:id
      #
      # Only the author. Deletes it with all its replies at any depth, and the
      # votes and favorites that hang from them, like the web. 204 without
      # body. The request body is not read.
      def destroy
        comment = find_comment
        authorize_owner!(comment)
        comment.destroy!

        head :no_content
      end

      private

      # Only the text: the author comes from the api-key and the submission from
      # the URL. Not `require`, which would answer 400 (not 422) to a blank body.
      # Used to create (API-07) and to edit (API-09) a comment.
      def comment_params
        params.permit(:body)
      end

      # The id comes from the URL path and not from `params`, which also reads
      # the request body: with a malformed JSON, `params` answers 400 before the
      # 404 or the 403 (docs/api-design.md §1: 401 -> 404 -> 403 -> 400).
      def find_comment
        Comment.find(request.path_parameters[:id])
        
      # `root` and its descendants, taken from `comments` (all the comments of
      # its submission) and in the same order. Not recursive, so a very deep
      # conversation cannot overflow the stack.
      def subtree(root, comments)
        children = comments.group_by(&:parent_id)
        ids = Set[root.id]
        queue = [ root.id ]
        until queue.empty?
          children.fetch(queue.shift, []).each do |child|
            ids << child.id
            queue << child.id
          end
        end
        comments.select { |c| ids.include?(c.id) }
      end
    end
  end
end
