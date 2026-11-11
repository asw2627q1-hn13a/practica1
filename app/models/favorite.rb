class Favorite < ApplicationRecord
  # ACT-05: a favorite on a Submission or a Comment.
  belongs_to :user
  belongs_to :favoritable, polymorphic: true

  # The same item can't be favorited twice by the same user.
  validates :user_id, uniqueness: { scope: [ :favoritable_type, :favoritable_id ] }
end
