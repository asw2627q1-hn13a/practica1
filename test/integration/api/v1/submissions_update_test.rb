require "test_helper"

# API-06: PUT /api/v1/submissions/:id, edit your own submission.
#
# Fixtures: url_high (alice, https://example.com/high, 100 points, 3 comments),
# url_low (bob, https://example.org/low) and ask_one (alice, no url, with text).
class Api::V1::SubmissionsUpdateTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @submission = submissions(:url_high)
    @ask = submissions(:ask_one)
  end

  # --- editing -----------------------------------------------------------------

  test "the owner edits title, url and text: 200 with the updated submission" do
    put_json @submission, { title: "New title", url: "https://www.new.example.com/a", text: "New text" }

    assert_response :ok
    assert_match %r{application/json}, response.media_type
    @submission.reload
    assert_equal "New title", @submission.title
    assert_equal "https://www.new.example.com/a", @submission.url
    assert_equal "New text", @submission.text
    assert_equal expected_json(@submission), json
    assert_equal "new.example.com", json["domain"]
    assert_not json.key?("comments")
  end

  test "only the fields sent change" do
    put_json @ask, { title: "Only the title" }

    assert_response :ok
    @ask.reload
    assert_equal "Only the title", @ask.title
    assert_nil @ask.url
    assert_equal "A question for the community", @ask.text
    assert_equal "ask", @ask.submission_type
  end

  test "the text can be removed" do
    put_json @ask, { text: nil }

    assert_response :ok
    assert_nil @ask.reload.text
    assert_nil json["text"]
  end

  test "fields that are not editable are ignored" do
    id = @submission.id
    created_at = @submission.created_at
    put_json @submission, {
      title: "Edited", id: 1, points: 999, comments_count: 77, submission_type: "ask",
      user_id: @bob.id, user: { id: @bob.id }, created_at: "2000-01-01T00:00:00Z"
    }

    assert_response :ok
    assert_equal id, json["id"]
    @submission.reload
    assert_equal "Edited", @submission.title
    assert_equal 100, @submission.points
    assert_equal 3, @submission.comments_count
    assert_equal "url", @submission.submission_type
    assert_equal @alice, @submission.user
    assert_equal created_at, @submission.created_at
  end

  test "a body without editable fields answers 200 and changes nothing" do
    @submission.update_columns(updated_at: 1.day.ago)
    before = @submission.reload.attributes

    [ {}, { points: 1 } ].each do |body|
      put_json @submission, body

      assert_response :ok
      assert_equal before, @submission.reload.attributes
      assert_equal expected_json(@submission), json
    end
  end

  # --- the type follows the url --------------------------------------------------

  test "removing the url turns it into an ask submission with url null" do
    [ "", "   ", nil ].each do |url|
      @submission.update_columns(url: "https://example.com/high", submission_type: "url")
      put_json @submission, { url: url }

      assert_response :ok
      @submission.reload
      assert_nil @submission.url, "url #{url.inspect}"
      assert_equal "ask", @submission.submission_type
      assert_nil json["url"]
      assert_nil json["domain"]
      assert_equal "ask", json["submission_type"]
    end
  end

  test "adding a url turns an ask submission into a url one" do
    put_json @ask, { url: "https://example.net/new" }

    assert_response :ok
    assert_equal "url", @ask.reload.submission_type
    assert_equal "url", json["submission_type"]
    assert_equal "example.net", json["domain"]
  end

  # --- validations ---------------------------------------------------------------

  test "a blank title is 422 and nothing changes" do
    [ "", "   ", nil ].each do |title|
      assert_no_changes -> { @submission.reload.attributes } do
        put_json @submission, { title: title, text: "Not saved" }
      end
      assert_validation_error "title" => [ "can't be blank" ]
    end
  end

  test "an invalid url is 422 and nothing changes" do
    assert_no_changes -> { @ask.reload.attributes } do
      put_json @ask, { url: "example.com", title: "Not saved" }
    end
    assert_validation_error "url" => [ "must start with http:// or https://" ]
  end

  test "a malformed JSON body is 400 and nothing changes" do
    assert_no_changes -> { @submission.reload.attributes } do
      put_raw @submission.id, '{"title":', user: @alice
    end
    assert_response :bad_request
    assert_equal "bad_request", json["error"]
  end

  # --- who can edit it -------------------------------------------------------------

  test "another user's api-key is 403 and nothing changes" do
    assert_no_changes -> { @submission.reload.attributes } do
      put_json @submission, { title: "Hacked" }, user: @bob
    end
    assert_response :forbidden
    assert_equal({ "error" => "forbidden", "message" => "You can only modify your own submissions" }, json)
  end

  test "a missing submission is 404" do
    put_raw 0, { title: "Hi" }.to_json, user: @alice

    assert_response :not_found
    assert_equal({ "error" => "not_found", "message" => "Submission with id=0 not found" }, json)
  end

  test "with a malformed body the order is still 404 and then 403" do
    put_raw 0, '{"title":', user: @alice
    assert_response :not_found

    put_raw @submission.id, '{"title":', user: @bob
    assert_response :forbidden
  end

  test "requires an api-key, even if the submission does not exist" do
    [ @submission.id, 0 ].each do |id|
      [ nil, "wrong" ].each do |key|
        put "/api/v1/submissions/#{id}", params: { title: "Hi" }.to_json,
            headers: { "Content-Type" => "application/json", "X-API-KEY" => key }.compact

        assert_response :unauthorized
        assert_equal "unauthorized", json["error"]
      end
    end
    assert_equal "A high ranked url submission", @submission.reload.title
  end

  private

  def put_json(submission, body, user: @alice)
    put_raw submission.id, body.to_json, user: user
  end

  def put_raw(id, raw_body, user:)
    put "/api/v1/submissions/#{id}", params: raw_body,
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
