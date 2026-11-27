require "test_helper"

# REST-01: el disseny de l'API (docs/api-design.md) fixat en forma de tests.
# Si algú canvia una URI o un verb sense actualitzar el disseny, falla aquí.
class ApiV1RoutesTest < ActionDispatch::IntegrationTest
  EXPECTED_ROUTES = [
    # Submissions
    [ "GET",    "/api/v1/submissions" ],
    [ "POST",   "/api/v1/submissions" ],
    [ "GET",    "/api/v1/submissions/:id" ],
    [ "PUT",    "/api/v1/submissions/:id" ],
    [ "DELETE", "/api/v1/submissions/:id" ],
    # Comments
    [ "GET",    "/api/v1/comments" ],
    [ "POST",   "/api/v1/submissions/:submission_id/comments" ],
    [ "POST",   "/api/v1/comments/:comment_id/replies" ],
    [ "GET",    "/api/v1/comments/:id" ],
    [ "PUT",    "/api/v1/comments/:id" ],
    [ "DELETE", "/api/v1/comments/:id" ],
    # Votes
    [ "POST",   "/api/v1/submissions/:submission_id/votes" ],
    [ "DELETE", "/api/v1/submissions/:submission_id/votes" ],
    [ "POST",   "/api/v1/comments/:comment_id/votes" ],
    [ "DELETE", "/api/v1/comments/:comment_id/votes" ],
    # Favorites
    [ "POST",   "/api/v1/submissions/:submission_id/favorites" ],
    [ "DELETE", "/api/v1/submissions/:submission_id/favorites" ],
    [ "POST",   "/api/v1/comments/:comment_id/favorites" ],
    [ "DELETE", "/api/v1/comments/:comment_id/favorites" ],
    # Hidden
    [ "POST",   "/api/v1/submissions/:submission_id/hidden" ],
    [ "DELETE", "/api/v1/submissions/:submission_id/hidden" ],
    # Users
    [ "GET",    "/api/v1/users/:id" ],
    [ "PUT",    "/api/v1/users/:id" ],
    [ "PUT",    "/api/v1/users/:id/images" ],
    [ "DELETE", "/api/v1/users/:id/images/:kind" ],
    [ "GET",    "/api/v1/users/:id/submissions" ],
    [ "GET",    "/api/v1/users/:id/comments" ],
    [ "GET",    "/api/v1/users/:id/threads" ],
    [ "GET",    "/api/v1/users/:id/favorites/submissions" ],
    [ "GET",    "/api/v1/users/:id/favorites/comments" ],
    [ "GET",    "/api/v1/users/:id/upvoted/submissions" ],
    [ "GET",    "/api/v1/users/:id/upvoted/comments" ],
    [ "GET",    "/api/v1/users/:id/hidden" ]
  ].freeze

  test "every endpoint of the API design is routed under /api/v1" do
    defined = api_routes
    EXPECTED_ROUTES.each do |verb, path|
      assert_includes defined, [ verb, path ], "Missing route: #{verb} #{path}"
    end
  end

  test "the API does not route login, registration or user creation" do
    defined = api_routes
    assert_not_includes defined, [ "POST", "/api/v1/users" ]
    assert_not_includes defined, [ "GET", "/api/v1/login" ]
  end

  test "unknown routes under /api/v1 answer 404 with the common JSON error" do
    %i[get post put delete].each do |verb|
      public_send(verb, "/api/v1/does-not-exist")

      assert_response :not_found
      assert_match %r{application/json}, response.media_type
      body = JSON.parse(response.body)
      assert_equal "not_found", body["error"]
      assert body["message"].present?
    end
  end

  private

  # [verb, path] de totes les rutes de l'API, sense el sufix (.:format).
  def api_routes
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      [ route.verb, path ] if path.start_with?("/api/v1")
    end
  end
end