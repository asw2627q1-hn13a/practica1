class Comment < ApplicationRecord
  belongs_to :user
  # counter_cache keeps submissions.comments_count up to date (counts every
  # comment on the submission, top-level ones and replies alike).
  belongs_to :submission, counter_cache: true

  # COM-02: a comment can be a reply to another comment, at any depth.
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true
  validate :parent_in_same_submission

  scope :chronological, -> { order(created_at: :asc) }
  # Top-level comments (not replies).
  scope :roots, -> { where(parent_id: nil) }

  private

  # A reply must hang under a comment of the same submission, so the tree
  # can't be corrupted by pointing a reply at an unrelated submission.
  def parent_in_same_submission
    return if parent.nil?

    if parent.submission_id != submission_id
      errors.add(:parent, "must belong to the same submission")
    end
  end
end
