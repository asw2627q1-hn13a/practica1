class Hide < ApplicationRecord
  # ACT-06: a user hides a submission from their own listings.
  belongs_to :user
  belongs_to :submission

  validates :user_id, uniqueness: { scope: :submission_id }
end
