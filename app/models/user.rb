class User < ApplicationRecord
  DEFAULT_IMAGES = {
    avatar: "default_avatar.png",
    banner: "default_banner.png"
  }.freeze

  has_one_attached :avatar
  has_one_attached :banner

  has_many :submissions, dependent: :destroy
  has_many :comments, dependent: :destroy
  # ACT-03/04/05/06: a user's actions.
  has_many :votes, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :hides, dependent: :destroy

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :username, presence: true, uniqueness: true

  # email is blank or follows the format "something@domain"
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # USR-05: every new user (OmniAuth sign-in or seeds) gets default images.
  after_create_commit :attach_default_images

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

  # ACT-06: submissions this user has hidden.
  def hidden_submissions
    Submission.where(id: hides.select(:submission_id))
  end

  # USR-05: attaches the default avatar and banner if the user has none.
  def attach_default_images
    DEFAULT_IMAGES.each do |name, filename|
      attachment = public_send(name)
      next if attachment.attached?

      attachment.attach(
        io: File.open(Rails.root.join("app/assets/images", filename)),
        filename: filename,
        content_type: "image/png"
      )
    end
  rescue StandardError => e
    # A storage failure (e.g. S3 unreachable) must not break sign-in.
    # The profile view falls back to the default assets if nothing is attached.
    Rails.logger.error("Could not attach default images to user #{id}: #{e.message}")
  end
end