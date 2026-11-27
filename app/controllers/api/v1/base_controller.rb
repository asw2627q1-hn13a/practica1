# REST-01: controlador base de l'API REST (/api/v1).
#
# Hereta d'ActionController::API (i no d'ApplicationController) perquè l'API no
# fa servir sessions, cookies, CSRF ni `allow_browser`: un client com curl o
# Postman no ha de rebre un 406 pensat per als navegadors de l'aplicació web.
#
# Defineix el format d'error comú de l'API (vegeu docs/api-design.md, §5). Només
# conté els helpers i els rescue_from; no té cap acció:
#
#   { "error": "not_found", "message": "...", "details": { ... } }
#
# `error` és un codi estable per a màquines, `message` un text per a persones i
# `details` és opcional (per exemple, els errors de validació per camp).
#
# API-02: autenticació amb api-key (vegeu docs/api-design.md, §1).
#
# - Tota petició ha de portar la capçalera `X-API-KEY`. El before_action
#   `authenticate_api_key!` busca l'usuari que en té aquella clau i el desa a
#   `current_user`; si falta o no coincideix amb cap usuari, respon 401 i
#   l'acció ja no s'executa.
# - L'usuari actiu (creador, votant...) és SEMPRE `current_user`, mai un camp
#   del cos de la petició.
# - Les accions que modifiquen contingut d'un usuari (PUT, DELETE) criden
#   `authorize_owner!(registre)`, que respon 403 si no és de `current_user`.
#   També accepta un User (el propietari és ell mateix).
module Api
  module V1
    class BaseController < ActionController::API
      # Excepció pròpia per al 403. authorize_owner! la llança des de dins
      # d'una acció: un `render` no aturaria el codi que ve després (p. ex. el
      # `destroy`), però una excepció sí.
      class ForbiddenError < StandardError; end

      ERROR_NAMES = {
        400 => "bad_request",
        401 => "unauthorized",
        403 => "forbidden",
        404 => "not_found",
        409 => "conflict",
        422 => "unprocessable_entity",
        500 => "internal_server_error"
      }.freeze

      # Rails comprova els rescue_from de l'últim al primer,
      # de manera que els handlers específics de sota tenen prioritat.
      # Un error inesperat respon 500 en JSON (sense exposar-ne el detall al
      # client) i queda al log.
      rescue_from StandardError do |e|
        Rails.logger.error("#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
        render_error(500, "Internal server error")
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        message = e.model ? "#{e.model} with id=#{e.id} not found" : "Resource not found"
        render_error(404, message)
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_validation_errors(e.record)
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error(400, "Missing required parameter: #{e.param}")
      end

      rescue_from ActionDispatch::Http::Parameters::ParseError do
        render_error(400, "Request body is not valid JSON")
      end

      rescue_from ForbiddenError do |e|
        render_error(403, e.message)
      end

      # S'executa abans de qualsevol acció de tots els controladors de l'API.
      before_action :authenticate_api_key!

      private

      # L'usuari propietari de l'api-key de la petició. Només és nil si
      # authenticate_api_key! ja ha respost 401 (i llavors l'acció no s'executa).
      attr_reader :current_user

      # 401 si la capçalera X-API-KEY falta o no correspon a cap usuari.
      # Com que fa `render`, Rails atura la cadena de filtres i l'acció no corre.
      def authenticate_api_key!
        api_key = request.headers["X-API-KEY"].presence
        @current_user = User.find_by(api_key: api_key) if api_key
        render_error(401, "API key is missing or invalid") unless @current_user
      end

      # 403 si `record` no és de l'usuari de l'api-key. Ús dins d'una acció,
      # després del `find` (així un id inexistent dona 404 i no 403):
      #
      #   authorize_owner!(submission)   # API-06, API-09: contingut propi
      #   authorize_owner!(user)         # API-15, API-16: el propi perfil
      #   authorize_owner!(user, message: "You can only see your own hidden submissions")  # API-17
      #
      # Un User no té user_id: el seu propietari és ell mateix. `message:` permet
      # un text propi quan l'acció no és modificar (p. ex. llistats privats).
      def authorize_owner!(record, message: nil)
        owner_id = record.is_a?(User) ? record.id : record.user_id
        return if owner_id == current_user.id

        raise ForbiddenError, message || forbidden_message(record)
      end

      # Missatge per defecte del 403 segons el tipus de registre.
      def forbidden_message(record)
        return "You can only modify your own profile" if record.is_a?(User)

        "You can only modify your own #{record.model_name.human.downcase.pluralize}"
      end

      # Resposta d'error amb el format comú. `status` és un enter (400, 401, 403,
      # 404, 409, 422 o 500).
      def render_error(status, message, details: nil)
        body = { error: ERROR_NAMES.fetch(status), message: message }
        body[:details] = details if details.present?
        render json: body, status: status
      end

      # 422: el model no passa les validacions; `details` té els errors per camp.
      def render_validation_errors(record)
        render_error(422, "Validation failed", details: record.errors.to_hash)
      end
    end
  end
end
