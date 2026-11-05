require "test_helper"

class OmniauthLoginTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github", uid: "123",
      info: { nickname: "alice", email: "alice@example.com" })
  end

  test "primer login crea l'usuari i el segon el reutilitza" do
    assert_difference("User.count", 1) { get "/auth/github/callback" }
    assert_no_difference("User.count")  { get "/auth/github/callback" }
  end
end