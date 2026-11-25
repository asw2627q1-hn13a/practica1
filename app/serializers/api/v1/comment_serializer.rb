module Api
  module V1
    # JSON representation of a comment (see docs/api-design.md §3).
    # Reused by the comment endpoints (API-07..10). It has only the common
    # fields: `replies` (trees) and `submission` (flat listings) are added by
    # the stories that need them.
    class CommentSerializer
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
