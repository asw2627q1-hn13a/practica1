class User < ApplicationRecord
  has_many :submissions, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :username, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    find_or_create_by!(provider: auth.provider, uid: auth.uid) do |user|
      user.username = auth.info.nickname
      user.email = auth.info.email
    end
  end

  # LST-01: karma shown next to the username in the top bar
  # (sum of the user's submission points, like Hacker News).
  def karma
    submissions.sum(:points)
  end
end