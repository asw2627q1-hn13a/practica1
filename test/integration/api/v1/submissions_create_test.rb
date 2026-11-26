require "test_helper"

# API-04: POST /api/v1/submissions, create a submission.
#
# Fixtures: url_high (alice, https://example.com/high), url_low (bob,
# https://example.org/low) and ask_one (alice, no url, with text).
class Api::V1::SubmissionsCreateTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  # --- creating -------------------------------------------------------------------

  test "with a url: 201 with the new url submission, created by the api-key user" do
    assert_difference "Submission.count", 1 do
      post_json({ title: "Show HN: My project", url: "https://www.github.com/foo/bar", text: "Some text" })
    end

    assert_response :created
    assert_match %r{application/json}, response.media_type
    submission = Submission.order(:id).last
    assert_equal "Show HN: My project", submission.title
    assert_equal "https://www.github.com/foo/bar", submission.url
    assert_equal "Some text", submission.text
    assert_equal "url", submission.submission_type
    assert_equal @alice, submission.user
    assert_equal 0, submission.points
    assert_equal 0, submission.comments_count
    assert_equal expected_json(submission), json
    assert_equal "github.com", json["domain"]
    assert_not json.key?("comments")
  end

  test "the creator is the api-key user" do
    post_json({ title: "From bob" }, user: @bob)

    assert_response :created
    assert_equal @bob, Submission.find(json["id"]).user
    assert_equal({ "id" => @bob.id, "username" => @bob.username }, json["user"])
  end

  test "without a url it is an ask submission with url null" do
    [ {}, { url: "" }, { url: "   " }, { url: nil } ].each do |url_field|
      post_json({ title: "Ask HN: something?", text: "The question" }.merge(url_field))

      assert_response :created
      submission = Submission.find(json["id"])
      assert_equal "ask", submission.submission_type
      assert_nil submission.url
      assert_equal "The question", submission.text
      assert_nil json["url"]
      assert_nil json["domain"]
    end
  end

  test "the text is optional" do
    post_json({ title: "Only a title", url: "https://example.net/only-title" })

    assert_response :created
    assert_nil Submission.find(json["id"]).text
    assert_nil json["text"]
  end

  test "fields that are not title, url or text are ignored" do
    post_json({
      title: "Created", url: "https://example.net/ignored", id: 1, points: 999, comments_count: 77,
      submission_type: "ask", user_id: @bob.id, user: { id: @bob.id }, created_at: "2000-01-01T00:00:00Z"
    })

    assert_response :created
    submission = Submission.find(json["id"])
    assert_not_equal 1, submission.id
    assert_equal 0, submission.points
    assert_equal 0, submission.comments_count
    assert_equal "url", submission.submission_type
    assert_equal @alice, submission.user
    assert_operator submission.created_at, :>, 1.minute.ago
  end

  test "the new submission is the first one in newest" do
    post_json({ title: "Brand new", url: "https://example.net/brand-new" })
    id = json["id"]

    get "/api/v1/submissions", params: { list: "newest" }, headers: { "X-API-KEY" => @bob.api_key }

    assert_response :ok
    assert_equal id, json.first["id"]
  end

  # --- validations ---------------------------------------------------------------

  test "a missing or blank title is 422 and nothing is created" do
    [ {}, { title: "" }, { title: "   " }, { title: nil } ].each do |title_field|
      assert_no_difference "Submission.count" do
        post_json({ url: "https://example.net/no-title" }.merge(title_field))
      end
      assert_validation_error "title" => [ "can't be blank" ]
    end
  end

  test "an invalid url is 422 and nothing is created" do
    assert_no_difference "Submission.count" do
      post_json({ title: "Bad url", url: "example.com" })
    end
    assert_validation_error "url" => [ "must start with http:// or https://" ]
  end

  test "a malformed JSON body is 400 and nothing is created" do
    assert_no_difference "Submission.count" do
      post_raw '{"title":', user: @alice
    end
    assert_response :bad_request
    assert_equal "bad_request", json["error"]
  end

  # --- url already submitted (409) ----------------------------------------------

  test "a url that another submission already has is 409 and nothing is created" do
    taken = submissions(:url_low) # bob's
    assert_no_difference "Submission.count" do
      post_json({ title: "Same url, other title", url: taken.url })
    end

    assert_response :conflict
    assert_equal({
      "error" => "conflict",
      "message" => "This URL has already been submitted",
      "details" => { "existing_submission_id" => taken.id }
    }, json)
    assert_nil response.headers["Location"]
  end

  test "it is also 409 if the submission with that url is of the same user" do
    taken = submissions(:url_high) # alice's
    assert_no_difference "Submission.count" do
      post_json({ title: "Again", url: taken.url })
    end

    assert_response :conflict
    assert_equal taken.id, json["details"]["existing_submission_id"]
  end

  test "two ask submissions do not conflict: they have no url" do
    assert_difference "Submission.count", 2 do
      post_json({ title: "First question" })
      post_json({ title: "Second question" })
    end
    assert_response :created
  end

  test "a blank title with a url already submitted is 422, not 409" do
    assert_no_difference "Submission.count" do
      post_json({ title: "", url: submissions(:url_high).url })
    end
    assert_validation_error "title" => [ "can't be blank" ]
  end

  # --- authentication ---------------------------------------------------------------

  test "requires an api-key and nothing is created without one" do
    [ nil, "wrong" ].each do |key|
      assert_no_difference "Submission.count" do
        post "/api/v1/submissions", params: { title: "Hi", url: "https://example.net/hi" }.to_json,
             headers: { "Content-Type" => "application/json", "X-API-KEY" => key }.compact
      end

      assert_response :unauthorized
      assert_equal "unauthorized", json["error"]
    end
  end

  private

  def post_json(body, user: @alice)
    post_raw body.to_json, user: user
  end

  def post_raw(raw_body, user:)
    post "/api/v1/submissions", params: raw_body,
         headers: { "Content-Type" => "application/json", "X-API-KEY" => user.api_key }
  end

  def json
    JSON.parse(response.body)
  end

  def assert_validation_error(details)
    assert_response :unprocessable_content
    assert_equal({ "error" => "unprocessable_entity", "message" => "Validation failed", "details" => details }, json)
  end

  # The exact representation of docs/api-design.md §3: no more and no fewer keys.
  def expected_json(submission)
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
end
