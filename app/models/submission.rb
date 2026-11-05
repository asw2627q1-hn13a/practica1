class Submission < ApplicationRecord
  belongs_to :user

  TYPES = %w[url ask].freeze

  validates :title, presence: true
  validates :submission_type, inclusion: { in: TYPES }

  # News: more relevant first. HN uses its own algorithm; for now, by points.
  scope :ranked, -> { order(points: :desc, created_at: :desc) }
  scope :of_type, ->(type) { where(submission_type: type) }

  # Domain shown next to the title on the news page (e.g. "github.com").
  def domain
    return nil if url.blank?

    host = URI.parse(url).host
    host&.delete_prefix("www.")
  rescue URI::InvalidURIError
    nil
  end
end
