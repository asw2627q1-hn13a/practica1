require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  # USR-03
  test "show works without login" do
    get user_url(@alice)
    assert_response :success
    assert_select "td", text: @alice.username
  end

  test "show returns 404 for a missing user" do
    get user_url(id: 0)
    assert_response :not_found
  end

  test "show hides the edit link from other users" do
    log_in_as(@bob)
    get user_url(@alice)
    assert_select "a[href=?]", edit_user_path(@alice), count: 0
  end

  # USR-04
  test "edit requires login" do
    get edit_user_url(@alice)
    assert_redirected_to login_path
  end

  test "update requires login" do
    patch user_url(@alice), params: { user: { about: "hacked" } }
    assert_redirected_to login_path
    assert_nil @alice.reload.about
  end

  test "user can open their own edit form" do
    log_in_as(@alice)
    get edit_user_url(@alice)
    assert_response :success
  end

  test "user can update their own about and see it on the profile" do
    log_in_as(@alice)
    patch user_url(@alice), params: { user: { about: "Hello, I am Alice" } }
    assert_redirected_to user_url(@alice)
    follow_redirect!
    assert_match "Hello, I am Alice", response.body
  end

  test "user cannot open another user's edit form" do
    log_in_as(@alice)
    get edit_user_url(@bob)
    assert_redirected_to user_url(@bob)
  end

  test "user cannot update another user's profile" do
    log_in_as(@alice)
    patch user_url(@bob), params: { user: { about: "hacked" } }
    assert_redirected_to user_url(@bob)
    assert_nil @bob.reload.about
  end

  test "username cannot be changed through update" do
    log_in_as(@alice)
    patch user_url(@alice), params: { user: { username: "mallory", about: "x" } }
    assert_equal "alice", @alice.reload.username
  end

  test "invalid email shows an error and is not saved" do
    log_in_as(@alice)
    patch user_url(@alice), params: { user: { email: "not-an-email" } }
    assert_response :unprocessable_content
    assert_equal "alice@example.com", @alice.reload.email
  end

  test "owner uploads a new avatar" do
    log_in_as(@alice)
    patch user_path(@alice), params: { user: { avatar: fixture_file_upload("avatar.png", "image/png") } }
    assert_redirected_to user_path(@alice)
    assert_equal "avatar.png", @alice.reload.avatar.filename.to_s
  end

  test "non-image upload shows an error" do
    log_in_as(@alice)
    patch user_path(@alice), params: { user: { avatar: fixture_file_upload("not_an_image.txt", "image/png") } }
    assert_response :unprocessable_content
  end
end