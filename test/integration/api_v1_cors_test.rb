require "test_helper"

# INF-05: CORS per a l'editor de Swagger (config/initializers/cors.rb).
#
# Els tests d'integració passen per tota la pila de middlewares, així que
# Rack::Cors hi actua igual que amb un navegador real. Aquí es fa el paper del
# navegador: capçalera Origin i, al preflight, Access-Control-Request-*.
class ApiV1CorsTest < ActionDispatch::IntegrationTest
  SWAGGER = "https://editor.swagger.io".freeze

  # --- preflight OPTIONS -------------------------------------------------------

  test "the preflight from the Swagger editor is accepted without api-key" do
    preflight "/api/v1/submissions", method: "POST", headers: "content-type, x-api-key"

    assert_response :ok
    assert_equal SWAGGER, response.headers["Access-Control-Allow-Origin"]
    allowed_methods = response.headers["Access-Control-Allow-Methods"].split(/,\s*/)
    assert_equal %w[GET POST PUT DELETE OPTIONS].sort, allowed_methods.sort
    assert_includes response.headers["Access-Control-Allow-Headers"].downcase, "x-api-key"
  end

  test "the preflight is accepted for every method the API uses" do
    %w[GET POST PUT DELETE].each do |verb|
      preflight "/api/v1/submissions/1", method: verb, headers: "x-api-key"

      assert_equal SWAGGER, response.headers["Access-Control-Allow-Origin"], "#{verb} not allowed"
    end
  end

  test "a preflight from another origin gets no CORS headers" do
    preflight "/api/v1/submissions", method: "POST", headers: "x-api-key", origin: "https://evil.example.com"

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "a preflight for a method the API does not use gets no CORS headers" do
    preflight "/api/v1/submissions/1", method: "PATCH", headers: "x-api-key"

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "a preflight asking for a header that is not allowed gets no CORS headers" do
    preflight "/api/v1/submissions", method: "POST", headers: "x-something-else"

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  # --- peticions normals -------------------------------------------------------

  test "API responses to the Swagger editor carry CORS headers, also errors" do
    get "/api/v1/does-not-exist", headers: { "Origin" => SWAGGER }

    assert_response :not_found
    assert_equal SWAGGER, response.headers["Access-Control-Allow-Origin"]
    assert_equal "not_found", JSON.parse(response.body)["error"]
  end

  test "the web application outside /api is not opened to other origins" do
    get "/", headers: { "Origin" => SWAGGER }

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  private

  def preflight(path, method:, headers:, origin: SWAGGER)
    process :options, path, headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => method,
      "Access-Control-Request-Headers" => headers
    }
  end
end
