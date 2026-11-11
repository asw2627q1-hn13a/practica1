require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  test "valid url submission" do
    submission = Submission.new(title: "Hi", url: "https://a.com", submission_type: "url", user: users(:alice))
    assert submission.valid?
  end

  test "title is required" do
    submission = Submission.new(submission_type: "url", user: users(:alice))
    assert_not submission.valid?
    assert_includes submission.errors[:title], "can't be blank"
  end

  test "submission_type must be url or ask" do
    submission = Submission.new(title: "Hi", submission_type: "video", user: users(:alice))
    assert_not submission.valid?
  end

  test "ranked orders by points descending" do
    assert_equal [ submissions(:url_high), submissions(:url_low) ],
                Submission.of_type("url").ranked.to_a
  end

  test "of_type filters by submission_type" do
    assert_not_includes Submission.of_type("url"), submissions(:ask_one)
    assert_includes Submission.of_type("ask"), submissions(:ask_one)
  end

  test "domain strips scheme and www" do
    submission = Submission.new(url: "https://www.github.com/rails/rails")
    assert_equal "github.com", submission.domain
  end

  test "domain is nil without url" do
    assert_nil Submission.new(url: nil).domain
  end

  # SUB-03 -------------------------------------------------------------------

  test "a url without http(s) scheme is invalid" do
    submission = Submission.new(title: "Hi", url: "example.com", submission_type: "url", user: users(:alice))
    assert_not submission.valid?
    assert submission.errors[:url].any?
  end

  test "a non-http url (ftp) is invalid" do
    submission = Submission.new(title: "Hi", url: "ftp://files.example.com", submission_type: "url", user: users(:alice))
    assert_not submission.valid?
  end

  test "a blank url is valid (it becomes an ask submission)" do
    submission = Submission.new(title: "Ask me", url: "", submission_type: "ask", user: users(:alice))
    assert submission.valid?
  end
end
