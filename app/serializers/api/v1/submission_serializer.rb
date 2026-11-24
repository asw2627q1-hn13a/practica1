module Api
  module V1
    # JSON representation of a submission (see docs/api-design.md §3).
    # Reused by the submission endpoints (API-03..06).
    class SubmissionSerializer
      def self.list(submissions)
        submissions.map { |submission| new(submission).as_json }
      end

      def initialize(submission)
        @submission = submission
      end

      def as_json(*)
        s = @submission
        {
          id: s.id,
          title: s.title,
          url: s.url,
          domain: s.domain,
          text: s.text,
          submission_type: s.submission_type,
          points: s.points,
          comments_count: s.comments_count,
          user: { id: s.user.id, username: s.user.username },
          created_at: s.created_at.utc.iso8601,
          updated_at: s.updated_at.utc.iso8601
        }
      end
    end
  end
end
