require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new user gets default avatar and banner" do
    user = User.create!(provider: "github", uid: "new-uid-123", username: "newuser")
    assert user.avatar.attached?
    assert user.banner.attached?
  end

  test "attach_default_images does not replace an existing avatar" do
    user = User.create!(provider: "github", uid: "new-uid-456", username: "other")
    original_blob = user.avatar.blob
    user.attach_default_images
    assert_equal original_blob, user.avatar.blob
  end

  test "accepts a valid image as avatar" do
    user = User.create!(provider: "github", uid: "img-1", username: "imguser")
    user.avatar = { io: File.open(file_fixture("avatar.png")),
                    filename: "avatar.png", content_type: "image/png" }
    assert user.valid?
  end

  test "rejects a non-image avatar even if named .png" do
    user = User.create!(provider: "github", uid: "img-2", username: "imguser2")
    user.avatar = { io: StringIO.new("this is not an image"),
                    filename: "avatar.png", content_type: "image/png" }
    assert_not user.valid?
    assert_includes user.errors[:avatar], "must be a PNG, JPEG, GIF or WebP image"
  end

  test "rejects an image larger than 5 MB" do
    user = User.create!(provider: "github", uid: "img-4", username: "imguser4")
    png_header = File.binread(file_fixture("avatar.png"), 16)
    user.avatar = { io: StringIO.new(png_header + ("0" * 6.megabytes)),
                    filename: "big.png", content_type: "image/png" }
    assert_not user.valid?
    assert_includes user.errors[:avatar], "must be smaller than 5 MB"
  end

  test "reset_to_default restores the default avatar" do
    user = User.create!(provider: "github", uid: "img-3", username: "imguser3")
    user.avatar.attach(io: File.open(file_fixture("avatar.png")),
                      filename: "mine.png", content_type: "image/png")
    user.reset_to_default(:avatar)
    assert_equal "default_avatar.png", user.avatar.filename.to_s
  end
end
