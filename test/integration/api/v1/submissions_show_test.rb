require "test_helper"

# API-05: GET /api/v1/submissions/:id, a submission with its comment tree.
#
# Fixtures: url_high (alice) has 3 comments: "first" (alice), "second" (bob) and
# "reply_to_first" (bob, a reply to "first"). url_low has 1 comment and ask_one
# has none.
class Api::V1::SubmissionsShowTest < ActionDispatch::IntegrationTest
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

  # --- the submission --------------------------------------------------------

  test "returns the submission data and its comment tree" do
    get_submission @submission

    assert_response :ok
    assert_match %r{application/json}, response.media_type
    assert_equal expected_submission(@submission.reload).merge(
      "comments" => [
        expected_comment(@first.reload, replies: [ expected_comment(@reply.reload) ]),
        expected_comment(@second.reload)
      ]
    ), json
  end

  test "a direct comment has no parent and a reply points to its parent" do
    get_submission @submission

    root = json["comments"].first
    assert_nil root["parent_id"]
    assert_equal @submission.id, root["submission_id"]
    assert_equal @first.id, root["replies"].first["parent_id"]
    assert_equal @submission.id, root["replies"].first["submission_id"]
  end

  test "a submission without comments has an empty array" do
    get_submission submissions(:ask_one)

    assert_response :ok
    assert_equal [], json["comments"]
    assert_equal 0, json["comments_count"]
    assert_equal "ask", json["submission_type"]
    assert_nil json["url"]
  end

  test "only includes the comments of that submission" do
    get_submission submissions(:url_low)

    assert_equal [ comments(:on_low).id ], json["comments"].map { |c| c["id"] }
  end

  test "a submission hidden by the api-key user is still returned" do
    @alice.hides.create!(submission: @submission)
    get_submission @submission

    assert_response :ok
    assert_equal @submission.id, json["id"]
  end

  test "any user can get a submission of another user" do
    get_submission @submission, user: @bob

    assert_response :ok
    assert_equal @alice.id, json["user"]["id"]
  end

  # --- order and depth -------------------------------------------------------

  test "comments are oldest first at every level, not by id or points" do
    # The oldest of each level is the last one created and has fewer points.
    @first.update_columns(points: 0)
    @second.update_columns(points: 50)
    old_root = add_comment("old root", created_at: 5.hours.ago)
    old_reply = add_comment("old reply", parent: @first, created_at: 2.hours.ago)
    get_submission @submission

    assert_equal [ old_root.id, @first.id, @second.id ], json["comments"].map { |c| c["id"] }
    replies = json["comments"].find { |c| c["id"] == @first.id }["replies"]
    assert_equal [ old_reply.id, @reply.id ], replies.map { |c| c["id"] }
  end

  test "comments with the same date are ordered by id" do
    date = 4.hours.ago
    created = 3.times.map { |i| add_comment("same date #{i}", created_at: date) }
    # Rewritten in reverse order so the database does not return them by id by chance.
    created.reverse_each { |c| c.update_columns(points: 1) }
    get_submission @submission

    assert_equal created.map(&:id).sort, json["comments"].first(3).map { |c| c["id"] }
  end

  test "a conversation of 60 levels is returned complete" do
    expected = [ @first.id ]
    parent = @first
    59.times do |i|
      parent = add_comment("level #{i}", parent: parent, created_at: 4.hours.ago)
      expected << parent.id
    end
    get_submission @submission
    assert_response :ok

    # Follow the branch down: the level of each comment must match.
    ids = []
    level = json["comments"].find { |c| c["id"] == @first.id }
    while level
      ids << level["id"]
      level = level["replies"].find { |c| expected.include?(c["id"]) }
    end
    assert_equal expected, ids
  end

  test "the number of queries does not grow with the number of comments" do
    before = count_queries { get_submission @submission }
    parent = @first
    5.times { |i| parent = add_comment("reply #{i}", parent: parent, created_at: 1.hour.ago) }

    assert_equal before, count_queries { get_submission @submission }
  end

  # --- errors ----------------------------------------------------------------

  test "a missing submission is 404 with the common JSON error" do
    get "/api/v1/submissions/0", headers: { "X-API-KEY" => @alice.api_key }

    assert_response :not_found
    assert_match %r{application/json}, response.media_type
    assert_equal({ "error" => "not_found", "message" => "Submission with id=0 not found" }, json)
  end

  test "requires an api-key, even if the submission does not exist" do
    [ @submission.id, 0 ].each do |id|
      [ {}, { "X-API-KEY" => "wrong" } ].each do |headers|
        get "/api/v1/submissions/#{id}", headers: headers

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
  end

  private

  def get_submission(submission, user: @alice)
    get "/api/v1/submissions/#{submission.id}", headers: { "X-API-KEY" => user.api_key }
  end

  # max_nesting: JSON.parse rejects more than 100 levels by default.
  def json
    JSON.parse(response.body, max_nesting: false)
  end

  def add_comment(body, created_at:, parent: nil)
    @submission.comments.create!(body: body, user: @bob, parent: parent, created_at: created_at)
  end

  # Cached queries count too: the query cache would hide repeated ones.
  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  # The exact representations of docs/api-design.md §3: no more and no fewer keys.
  def expected_submission(submission)
    {
      "id" => submission.id,
      "title" => submission.title,
      "url" => submission.url,
      "domain" => submission.domain,
      "text" => submission.text,
      "submission_type" => submission.submission_type,
      "points" => submission.points,
      "comments_count" => submission.comments_count,
      "user" => { "id" => submission.user.id, "username" => submission.user.username },
      "created_at" => submission.created_at.utc.iso8601,
      "updated_at" => submission.updated_at.utc.iso8601
    }
  end

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
