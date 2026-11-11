class User < ApplicationRecord
  DEFAULT_IMAGES = {
    avatar: "default_avatar.png",
    banner: "default_banner.png"
  }.freeze

  # USR-06: allowed uploads for avatar and banner.
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes

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

  # USR-06: a new upload must be a real image (checked by content, not by name).
  validate :images_must_be_valid

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

  # USR-06: "delete" on the profile form goes back to the default image.
  def reset_to_default(name)
    public_send(name).purge
    attach_default_images
  end

  private

  # Only validates files that are being uploaded now, so saving the user
  # does not re-read images already stored in the bucket.
  def images_must_be_valid
    %i[avatar banner].each do |name|
      io = pending_upload_io(name)
      next unless io

      io.rewind
      detected_type = Marcel::MimeType.for(io) # detects the file type based on the content
      io.rewind

      unless ALLOWED_IMAGE_TYPES.include?(detected_type)
        errors.add(name, "must be a PNG, JPEG, GIF or WebP image")
      end
      errors.add(name, "must be smaller than 5 MB") if io.size > MAX_IMAGE_SIZE
    end
  end

  # The IO of a file assigned to the attachment but not saved yet (nil if none).
  def pending_upload_io(name)
    attachable = attachment_changes[name.to_s]&.attachable
    if attachable.respond_to?(:tempfile)
      attachable.tempfile
    elsif attachable.is_a?(Hash)
      attachable[:io]
    end
  end
end