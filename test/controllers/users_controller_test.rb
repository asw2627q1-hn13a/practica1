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

  # USR-07
  test "profile has the four activity links" do
    get user_url(@alice)
    assert_select "a[href=?]", submissions_user_path(@alice)
    assert_select "a[href=?]", threads_path(id: @alice.id)
    assert_select "a[href=?]", favorite_submissions_user_path(@alice)
    assert_select "a[href=?]", favorite_comments_user_path(@alice)
  end

  test "submissions opens a new tab and lists only that user's, newest first" do
    old = Submission.create!(title: "Alice old", url: "https://example.com/old",
                             submission_type: "url", user: @alice, created_at: 2.days.ago)
    get submissions_user_url(@alice)
    assert_response :success
    assert_select ".hn-nav a.current", text: "alice's submissions"
    assert_match "A high ranked url submission", response.body
    assert_match "Ask HN about something", response.body
    assert_no_match "A low ranked url submission", response.body # bob's
    assert response.body.index("Ask HN about something") < response.body.index(old.title)
  end

  test "threads filtered by user id is public and shows that user's comments" do
    get threads_url(id: @alice.id)
    assert_response :success
    assert_select ".hn-nav a.current", text: "threads"
    assert_match "A first comment on the high submission", response.body
    assert_match "A reply to the first comment", response.body # reply received
    assert_no_match "A reply-worthy second comment", response.body # bob's own comment
  end

  test "threads filtered by a missing user id is a 404" do
    get threads_url(id: 0)
    assert_response :not_found
  end

  test "threads without id still needs login" do
    get threads_url
    assert_redirected_to login_path
  end

  test "favorite submissions is the default of the favorites tab" do
    Favorite.create!(user: @bob, favoritable: submissions(:url_high))
    Favorite.create!(user: @bob, favoritable: comments(:first))
    Favorite.create!(user: @alice, favoritable: submissions(:url_low))
    get favorite_submissions_user_url(@bob)
    assert_response :success
    assert_select ".hn-nav a.current", text: "favorites"
    assert_select ".favorites-nav a[href=?]", favorite_comments_user_path(@bob)
    assert_match "A high ranked url submission", response.body
    assert_no_match "A first comment on the high submission", response.body
    assert_no_match "A low ranked url submission", response.body # alice's favorite
  end

  test "favorite comments shows only the user's favorite comments" do
    Favorite.create!(user: @bob, favoritable: submissions(:url_high))
    Favorite.create!(user: @bob, favoritable: comments(:first))
    get favorite_comments_user_url(@bob)
    assert_response :success
    assert_select ".hn-nav a.current", text: "favorites"
    assert_match "A first comment on the high submission", response.body
    assert_no_match "Ask HN about something", response.body
  end

  test "empty activity listings show a message" do
    carol = User.create!(username: "carol", provider: "github", uid: "3")
    get submissions_user_url(carol)
    assert_match "No submissions yet", response.body
    get favorite_submissions_user_url(carol)
    assert_match "No favorite submissions yet", response.body
    get favorite_comments_user_url(carol)
    assert_match "No favorite comments yet", response.body
    get threads_url(id: carol.id)
    assert_match "carol hasn", response.body
  end

  test "activity listings return 404 for a missing user" do
    get submissions_user_url(id: 0)
    assert_response :not_found
    get favorite_submissions_user_url(id: 0)
    assert_response :not_found
    get favorite_comments_user_url(id: 0)
    assert_response :not_found
  end

  # USR-08
  test "profile shows hidden and upvoted links only to its owner" do
    log_in_as(@alice)
    get user_url(@alice)
    assert_select "a[href=?]", hidden_path
    assert_select "a[href=?]", upvoted_path
    get user_url(@bob)
    assert_select "a[href=?]", hidden_path, count: 0
    assert_select "a[href=?]", upvoted_path, count: 0
  end

  test "profile hides the hidden and upvoted links when logged out" do
    get user_url(@alice)
    assert_select "a[href=?]", upvoted_path, count: 0
  end

  test "upvoted requires login" do
    get upvoted_url
    assert_redirected_to login_path
  end

  test "upvoted shows my voted submissions by default, with unvote" do
    Vote.create!(user: @alice, votable: submissions(:url_low))
    Vote.create!(user: @alice, votable: comments(:second))
    Vote.create!(user: @bob, votable: submissions(:ask_one)) # someone else's vote
    log_in_as(@alice)
    get upvoted_url
    assert_response :success
    assert_select ".hn-nav a.current", text: "upvoted"
    assert_select ".favorites-nav a[href=?]", upvoted_comments_path
    assert_match "A low ranked url submission", response.body
    assert_no_match "A reply-worthy second comment", response.body
    assert_no_match "Ask HN about something", response.body
    assert_select "form[action=?]", unvote_submission_path(submissions(:url_low))
  end

  test "upvoted comments shows my voted comments, with unvote" do
    Vote.create!(user: @alice, votable: submissions(:url_low))
    Vote.create!(user: @alice, votable: comments(:second))
    log_in_as(@alice)
    get upvoted_comments_url
    assert_response :success
    assert_select ".hn-nav a.current", text: "upvoted"
    assert_match "A reply-worthy second comment", response.body
    assert_select "form[action=?]", unvote_comment_path(comments(:second))
  end

  test "upvoted comments requires login" do
    get upvoted_comments_url
    assert_redirected_to login_path
  end

  test "unvoting from the upvoted page removes it from the list" do
    Vote.create!(user: @alice, votable: submissions(:url_low))
    log_in_as(@alice)
    post unvote_submission_url(submissions(:url_low)), headers: { "HTTP_REFERER" => upvoted_url }
    assert_redirected_to upvoted_url
    follow_redirect!
    assert_no_match "A low ranked url submission", response.body
  end
end