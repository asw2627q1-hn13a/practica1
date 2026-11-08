class Comment < ApplicationRecord
  belongs_to :user
  # counter_cache keeps submissions.comments_count up to date.
  belongs_to :submission, counter_cache: true

  validates :body, presence: true

  scope :chronological, -> { order(created_at: :asc) }
end
