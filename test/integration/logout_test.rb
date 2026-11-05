require "test_helper"

class LogoutTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "123",
      info: { nickname: "lkjhg", email: "lkjhg@example.com" }
    )
    get "/auth/github/callback"   # deixa l'usuari loguejat abans de cada test
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "l'usuari loguejat veu el botó logout al capçal" do
    get login_path
    assert_select "a[href=?][data-turbo-method=delete]", logout_path, text: "logout"
  end

  test "logout tanca la sessió i torna a la pàgina principal" do
    delete logout_path

    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "després del logout ja no es veu el botó logout i es veu login" do
    delete logout_path
    get login_path

    assert_select "form[action=?]", logout_path, count: 0
    assert_select "a[href=?]", login_path
  end
end