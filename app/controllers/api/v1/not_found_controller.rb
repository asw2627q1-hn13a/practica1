# REST-01: destí de la ruta comodí de /api (vegeu el final de config/routes.rb).
# Qualsevol URL o verb que l'API no defineix respon 404 amb el format d'error
# comú. (No es respon 405 + Allow: vegeu docs/api-design.md, §1.)
module Api
  module V1
    class NotFoundController < BaseController
      # Una ruta inexistent és 404 amb api-key o sense (API-02): no revela cap
      # dada i el disseny diu que tot /api/* que no existeix respon 404.
      skip_before_action :authenticate_api_key!

      def show
        render_error(404, "No route matches #{request.request_method} #{request.path}")
      end
    end
  end
end
