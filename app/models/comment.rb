class Comment < ApplicationRecord
  belongs_to :user
  # counter_cache keeps submissions.comments_count up to date (counts every
  # comment on the submission, top-level ones and replies alike).
  belongs_to :submission, counter_cache: true

  # COM-02: a comment can be a reply to another comment, at any depth.
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy
  # ACT-04/05: actions a user can take on a comment.
  has_many :votes, as: :votable, dependent: :destroy
  has_many :favorites, as: :favoritable, dependent: :destroy

  validates :body, presence: true
  validate :parent_in_same_submission

  scope :chronological, -> { order(created_at: :asc) }
  # Newest first (LST-02 / LST-03 listings).
  scope :by_recent, -> { order(created_at: :desc) }
  # Top-level comments (not replies).
  scope :roots, -> { where(parent_id: nil) }

  # Action-state helpers used by the views (ACT-01, ACT-02, ACT-04, ACT-05).
  def owned_by?(a_user)
    a_user.present? && user_id == a_user.id
  end

  def voted_by?(a_user)
    a_user.present? && votes.exists?(user_id: a_user.id)
  end

  def favorited_by?(a_user)
    a_user.present? && favorites.exists?(user_id: a_user.id)
  end

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
