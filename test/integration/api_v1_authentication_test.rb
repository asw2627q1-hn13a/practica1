require "test_helper"

# API-02: autenticació amb api-key i comprovació de propietari.
#
# Encara no hi ha endpoints reals (són API-03..17), així que es prova
# Api::V1::BaseController amb un controlador de prova que només existeix aquí.
# `with_routing` substitueix les rutes de l'app per aquestes durant cada test.
class ApiAuthProbeController < Api::V1::BaseController
  # Retorna qui és l'usuari actiu segons l'api-key.
  def show
    render json: { id: current_user.id, username: current_user.username }
  end

  # Esborra una submission només si és de l'usuari de l'api-key.
  def destroy
    submission = Submission.find(params[:id])
    authorize_owner!(submission)
    submission.destroy!
    head :no_content
  end
end

class ApiV1AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @alice_submission = submissions(:url_high) # user: alice
  end

  # --- api-key absent o incorrecta: 401 ---------------------------------------

  test "a request without api-key answers 401 with the common JSON error" do
    with_probe_routes do
      get "/api/v1/probe"

      assert_unauthorized
    end
  end

  test "a request with an empty api-key answers 401" do
    with_probe_routes do
      get "/api/v1/probe", headers: { "X-API-KEY" => "" }

      assert_unauthorized
    end
  end

  test "a request with a wrong api-key answers 401" do
    with_probe_routes do
      get "/api/v1/probe", headers: { "X-API-KEY" => "this-key-does-not-exist" }

      assert_unauthorized
    end
  end

  test "without api-key it is 401 even if the resource does not exist" do
    with_probe_routes do
      delete "/api/v1/probe/0"

      assert_unauthorized
    end
  end

  # --- api-key correcta: l'usuari actiu surt de l'api-key ---------------------

  test "a correct api-key identifies its user" do
    with_probe_routes do
      get "/api/v1/probe", headers: auth(@alice)

      assert_response :ok
      assert_equal({ "id" => @alice.id, "username" => "alice" }, JSON.parse(response.body))
    end
  end

  test "the active user comes from the api-key, never from the request body" do
    with_probe_routes do
      post "/api/v1/probe", params: { user_id: @bob.id }.to_json,
                            headers: auth(@alice).merge("Content-Type" => "application/json")

      assert_response :ok
      assert_equal @alice.id, JSON.parse(response.body)["id"]
    end
  end

  # --- propietari: 403 si és d'un altre usuari --------------------------------

  test "an api-key of another user cannot modify the content: 403 and nothing changes" do
    with_probe_routes do
      assert_no_difference "Submission.count" do
        delete "/api/v1/probe/#{@alice_submission.id}", headers: auth(@bob)
      end

      assert_response :forbidden
      body = JSON.parse(response.body)
      assert_equal "forbidden", body["error"]
      assert_equal "You can only modify your own submissions", body["message"]
    end
  end

  test "the owner's api-key can modify the content" do
    with_probe_routes do
      assert_difference "Submission.count", -1 do
        delete "/api/v1/probe/#{@alice_submission.id}", headers: auth(@alice)
      end

      assert_response :no_content
    end
  end

  test "with a valid api-key a missing resource is 404, not 403" do
    with_probe_routes do
      delete "/api/v1/probe/0", headers: auth(@bob)

      assert_response :not_found
    end
  end

  # --- rutes inexistents: continuen sent 404 sense api-key --------------------

  test "unknown API routes still answer 404 without api-key" do
    get "/api/v1/does-not-exist"

    assert_response :not_found
    assert_equal "not_found", JSON.parse(response.body)["error"]
  end

  private

  def auth(user)
    { "X-API-KEY" => user.api_key }
  end

  def with_probe_routes(&block)
    with_routing do |set|
      set.draw do
        get    "/api/v1/probe",     to: "api_auth_probe#show"
        post   "/api/v1/probe",     to: "api_auth_probe#show"
        delete "/api/v1/probe/:id", to: "api_auth_probe#destroy"
      end
      block.call
    end
  end

  def assert_unauthorized
    assert_response :unauthorized
    assert_match %r{application/json}, response.media_type
    body = JSON.parse(response.body)
    assert_equal "unauthorized", body["error"]
    assert_equal "API key is missing or invalid", body["message"]
  end
end
