require "test_helper"

# API-08: GET /api/v1/comments/:id, a comment with its complete subtree.
#
# Fixtures: url_high (alice) has 3 comments: "first" (alice), "second" (bob) and
# "reply_to_first" (bob, a reply to "first"). url_low has "on_low" (alice).
class Api::V1::CommentsShowTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @submission = submissions(:url_high)
    @first = comments(:first)
    @second = comments(:second)
    @reply = comments(:reply_to_first)
    # Fixtures share the same created_at: give them an explicit order.
    @first.update_columns(created_at: 3.hours.ago)
    @second.update_columns(created_at: 2.hours.ago)
    @reply.update_columns(created_at: 1.hour.ago)
  end

  # --- the comment and its subtree -------------------------------------------

  test "returns the comment with its subtree and its submission" do
    get_comment @first

    assert_response :ok
    assert_match %r{application/json}, response.media_type
    assert_equal expected_comment(@first.reload, replies: [ expected_comment(@reply.reload) ])
                   .merge("submission" => submission_ref(@submission)), json
  end

  test "a direct comment has no parent" do
    get_comment @first

    assert_nil json["parent_id"]
    assert_equal @submission.id, json["submission_id"]
  end

  test "a reply points to its parent and to its submission" do
    get_comment @reply

    assert_response :ok
    assert_equal @first.id, json["parent_id"]
    assert_equal @submission.id, json["submission_id"]
    assert_equal submission_ref(@submission), json["submission"]
    assert_equal [], json["replies"]
  end

  test "only includes the descendants of the comment" do
    grandchild = add_comment("reply to the reply", parent: @reply, created_at: 30.minutes.ago)
    reply_to_second = add_comment("reply to second", parent: @second, created_at: 30.minutes.ago)
    get_comment @first

    ids = all_ids(json)
    assert_equal [ @first.id, @reply.id, grandchild.id ].sort, ids.sort
    assert_not_includes ids, @second.id
    assert_not_includes ids, reply_to_second.id
    assert_not_includes ids, comments(:on_low).id
  end

  test "the subtree of a reply does not include its parent" do
    get_comment @reply

    assert_equal [ @reply.id ], all_ids(json)
  end

  test "any user can get a comment of another user" do
    get_comment @first, user: @bob

    assert_response :ok
    assert_equal @alice.id, json["user"]["id"]
  end

  # --- order and depth -------------------------------------------------------

  test "replies are oldest first at every level, not by id or points" do
    # old_reply is created later (bigger id) but is older, and has fewer points.
    @reply.update_columns(points: 50)
    old_reply = add_comment("old reply", parent: @first, created_at: 2.hours.ago)
    newer = add_comment("newer grandchild", parent: @reply, created_at: 10.minutes.ago)
    older = add_comment("older grandchild", parent: @reply, created_at: 20.minutes.ago)
    get_comment @first

    assert_equal [ old_reply.id, @reply.id ], json["replies"].map { |c| c["id"] }
    reply = json["replies"].find { |c| c["id"] == @reply.id }
    assert_equal [ older.id, newer.id ], reply["replies"].map { |c| c["id"] }
  end

  test "replies with the same date are ordered by id" do
    date = 30.minutes.ago
    created = 3.times.map { |i| add_comment("same date #{i}", parent: @first, created_at: date) }
    # Rewritten in reverse order so the database does not return them by id by chance.
    created.reverse_each { |c| c.update_columns(points: 1) }
    get_comment @first

    # @reply (1 hour ago) goes first; then the three of the same date.
    assert_equal created.map(&:id).sort, json["replies"].last(3).map { |c| c["id"] }
  end

  test "a conversation of 60 levels is returned complete" do
    expected = [ @first.id ]
    parent = @first
    59.times do |i|
      parent = add_comment("level #{i}", parent: parent, created_at: 30.minutes.ago)
      expected << parent.id
    end
    get_comment @first
    assert_response :ok

    # Follow the branch down: the level of each comment must match.
    ids = []
    level = json
    while level
      ids << level["id"]
      level = level["replies"].find { |c| expected.include?(c["id"]) }
    end
    assert_equal expected, ids
  end

  test "the number of queries does not grow with the number of replies" do
    before = count_queries { get_comment @first }
    parent = @first
    5.times { |i| parent = add_comment("reply #{i}", parent: parent, created_at: 30.minutes.ago) }

    assert_equal before, count_queries { get_comment @first }
  end

  # --- errors ----------------------------------------------------------------

  test "a missing comment is 404 with the common JSON error" do
    get "/api/v1/comments/0", headers: { "X-API-KEY" => @alice.api_key }

    assert_response :not_found
    assert_match %r{application/json}, response.media_type
    assert_equal({ "error" => "not_found", "message" => "Comment with id=0 not found" }, json)
  end

  test "requires an api-key, even if the comment does not exist" do
    [ @first.id, 0 ].each do |id|
      [ {}, { "X-API-KEY" => "wrong" } ].each do |headers|
        get "/api/v1/comments/#{id}", headers: headers

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
  end

  private

  def get_comment(comment, user: @alice)
    get "/api/v1/comments/#{comment.id}", headers: { "X-API-KEY" => user.api_key }
  end

  # max_nesting: JSON.parse rejects more than 100 levels by default.
  def json
    JSON.parse(response.body, max_nesting: false)
  end

  def add_comment(body, created_at:, parent:)
    @submission.comments.create!(body: body, user: @bob, parent: parent, created_at: created_at)
  end

  # Cached queries count too: the query cache would hide repeated ones.
  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  # Every id of the tree, at any depth (without recursion).
  def all_ids(node)
    ids = []
    stack = [ node ]
    until stack.empty?
      current = stack.pop
      ids << current["id"]
      stack.concat(current["replies"])
    end
    ids
  end

  def submission_ref(submission)
    { "id" => submission.id, "title" => submission.title }
  end

  # The exact representation of docs/api-design.md §3: no more and no fewer keys.
  def expected_comment(comment, replies: [])
    {
      "id" => comment.id,
      "body" => comment.body,
      "points" => comment.points,
      "user" => { "id" => comment.user.id, "username" => comment.user.username },
      "submission_id" => comment.submission_id,
      "parent_id" => comment.parent_id,
      "created_at" => comment.created_at.utc.iso8601,
      "updated_at" => comment.updated_at.utc.iso8601,
      "replies" => replies
    }
  end
end
