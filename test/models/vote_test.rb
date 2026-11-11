require "test_helper"

class VoteTest < ActiveSupport::TestCase
  test "a user can vote a given item only once" do
    submission = submissions(:url_low)
    assert Vote.create(user: users(:alice), votable: submission).persisted?
    duplicate = Vote.new(user: users(:alice), votable: submission)
    assert_not duplicate.valid?
  end

  test "votes are polymorphic over submissions and comments" do
    assert Vote.create(user: users(:alice), votable: submissions(:url_low)).persisted?
    assert Vote.create(user: users(:alice), votable: comments(:second)).persisted?
  end
end
