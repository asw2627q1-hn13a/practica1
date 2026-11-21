# REST-01: controlador base de l'API REST (/api/v1).
#
# Hereta d'ActionController::API (i no d'ApplicationController) perquè l'API no
# fa servir sessions, cookies, CSRF ni `allow_browser`: un client com curl o
# Postman no ha de rebre un 406 pensat per als navegadors de l'aplicació web.
#
# Defineix el format d'error comú de l'API (vegeu docs/api-design.md, §5):
#
#   { "error": "not_found", "message": "...", "details": { ... } }
#
# `error` és un codi estable per a màquines, `message` un text per a persones i
# `details` és opcional (per exemple, els errors de validació per camp).
#
# L'autenticació amb api-key NO és aquí: és l'abast d'API-02. Quan estigui feta,
# s'hi afegirà un before_action que usarà `render_error(401, ...)` i
# `render_error(403, ...)`.
module Api
  module V1
    class BaseController < ActionController::API
      ERROR_NAMES = {
        400 => "bad_request",
        401 => "unauthorized",
        403 => "forbidden",
        404 => "not_found",
        409 => "conflict",
        422 => "unprocessable_entity"
      }.freeze

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

      # Destí de la ruta comodí de /api/v1 (vegeu config/routes.rb).
      def route_not_found
        render_error(404, "No route matches #{request.request_method} #{request.path}")
      end

      private

      # Resposta d'error amb el format comú. `status` és un enter (400, 401, 403,
      # 404, 409 o 422); `headers` permet, per exemple, afegir Location en un 409.
      def render_error(status, message, details: nil, headers: {})
        body = { error: ERROR_NAMES.fetch(status), message: message }
        body[:details] = details if details.present?
        headers.each { |name, value| response.set_header(name, value) }
        render json: body, status: status
      end

      # 422: el model no passa les validacions; `details` té els errors per camp.
      def render_validation_errors(record)
        render_error(422, "Validation failed", details: record.errors.to_hash)
      end
    end
  end
end