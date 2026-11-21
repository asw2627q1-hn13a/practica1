# REST-01: destí de la ruta comodí de /api (vegeu el final de config/routes.rb).
# Qualsevol URL o verb que l'API no defineix respon 404 amb el format d'error
# comú. (No es respon 405 + Allow: vegeu docs/api-design.md, §1.)
module Api
  module V1
    class NotFoundController < BaseController
      def show
        render_error(404, "No route matches #{request.request_method} #{request.path}")
      end
    end
  end
end