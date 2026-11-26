module Api
  module V1
    # JSON representation of a comment (see docs/api-design.md §3).
    # Reused by the comment endpoints (API-07..10). `as_json` has only the
    # common fields; the flat listings add `submission` (`flat`) and the
    # threads add `submission` and `replies` (`thread`).
    class CommentSerializer
      def self.list(comments)
        comments.map { |comment| new(comment).as_json }
      end

      # API-10: flat listing (GET /comments): adds the submission the comment
      # belongs to. Callers should `includes(:user, :submission)`.
      def self.flat(comments)
        comments.map { |comment| new(comment).as_json.merge(submission: submission_ref(comment)) }
      end

      # API-10: a comment of GET /users/:id/threads: adds the submission it
      # belongs to and the replies it received (already loaded and ordered by
      # the caller; they are plain comments, without their own replies).
      def self.thread(comment, replies)
        new(comment).as_json.merge(submission: submission_ref(comment), replies: list(replies))
      end

      def self.submission_ref(comment)
        { id: comment.submission.id, title: comment.submission.title }
      end

      def initialize(comment)
        @comment = comment
      end

      def as_json(*)
        c = @comment
        {
          id: c.id,
          body: c.body,
          points: c.points,
          user: { id: c.user.id, username: c.user.username },
          submission_id: c.submission_id,
          parent_id: c.parent_id,
          created_at: c.created_at.utc.iso8601,
          updated_at: c.updated_at.utc.iso8601
        }
      end
    end
  end
end