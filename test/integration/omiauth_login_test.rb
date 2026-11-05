require "test_helper"

class OmniauthLoginTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "123",
      info: { nickname: "lkjhg", email: "lkjhg@example.com" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "el primer login crea l'usuari i el segon el reutilitza" do
    assert_difference("User.count", 1) do
      get "/auth/github/callback"
    end

    assert_no_difference("User.count") do
      get "/auth/github/callback"
    end
  end

  test "el login desa les dades del proveïdor" do
    get "/auth/github/callback"

    user = User.find_by(provider: "github", uid: "123")
    assert_equal "lkjhg", user.username
    assert_equal "lkjhg@example.com", user.email
  end
end