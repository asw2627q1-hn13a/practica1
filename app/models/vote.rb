class Vote < ApplicationRecord
  # ACT-03 / ACT-04: a vote on a Submission or a Comment.
  belongs_to :user
  belongs_to :votable, polymorphic: true

  # A user can vote a given item at most once.
  validates :user_id, uniqueness: { scope: [ :votable_type, :votable_id ] }
end
