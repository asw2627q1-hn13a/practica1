class User < ApplicationRecord
  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  def self.from_omniauth(auth)
    find_or_create_by!(provider: auth.provider, uid: auth.uid) do |user|
      user.username = auth.info.nickname
      user.email = auth.info.email
    end
  end
end