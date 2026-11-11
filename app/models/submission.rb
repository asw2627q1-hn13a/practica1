class Submission < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  # ACT-03/05/06: actions a user can take on a submission.
  has_many :votes, as: :votable, dependent: :destroy
  has_many :favorites, as: :favoritable, dependent: :destroy
  has_many :hides, dependent: :destroy

  TYPES = %w[url ask].freeze

  validates :title, presence: true
  validates :submission_type, inclusion: { in: TYPES }
  # SUB-03: when a url is given it must be a valid http(s) url. A blank url is
  # not an error — the submission simply becomes an "ask".
  validate :url_must_be_http, if: -> { url.present? }

  # News: more relevant first. HN uses its own algorithm; for now, by points.
  scope :ranked, -> { order(points: :desc, created_at: :desc) }
  # Newest: most recent first.
  scope :by_time, -> { order(created_at: :desc) }
  scope :of_type, ->(type) { where(submission_type: type) }

  # SUB-02: type depends on whether a url was provided.
  # url present -> "url"; url blank -> "ask".
  def assign_type_from_url
    self.submission_type = url.present? ? "url" : "ask"
  end

  # Domain shown next to the title on the news page (e.g. "github.com").
  def domain
    return nil if url.blank?

    host = URI.parse(url).host
    host&.delete_prefix("www.")
  rescue URI::InvalidURIError
    nil
  end

  private

  # SUB-03: a url is valid only if it parses as http/https with a host.
  def url_must_be_http
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) && uri.host.present?
      errors.add(:url, "must start with http:// or https://")
    end
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  # Action-state helpers used by the views (ACT-01..06).
  def owned_by?(a_user)
    a_user.present? && user_id == a_user.id
  end

  def voted_by?(a_user)
    a_user.present? && votes.exists?(user_id: a_user.id)
  end

  def favorited_by?(a_user)
    a_user.present? && favorites.exists?(user_id: a_user.id)
  end

  def hidden_by?(a_user)
    a_user.present? && hides.exists?(user_id: a_user.id)
  end
end
