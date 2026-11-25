# INF-05: CORS (Cross-Origin Resource Sharing) per a l'editor de Swagger.
#
# Quan https://editor.swagger.io crida l'API des del navegador, és una petició
# d'un altre origen. Abans de les peticions "no simples" (POST/PUT/DELETE, JSON
# o qualsevol amb la capçalera X-API-KEY) el navegador envia una petició
# preflight OPTIONS i només continua si la resposta porta les capçaleres
# Access-Control-Allow-* adequades.
#
# Rack::Cors és un middleware: es col·loca el primer de la pila (posició 0)
# perquè respongui el preflight ell mateix, abans d'arribar a Rails. Així el
# preflight (que el navegador envia sense api-key) no topa amb el 401 d'API-02
# ni amb cap ruta. A les respostes normals (també les d'error 401/404/...) hi
# afegeix les capçaleres CORS perquè el navegador deixi llegir el JSON.
#
# Només s'obre /api/*: la resta de l'aplicació web no accepta altres orígens.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://editor.swagger.io"

    resource "/api/*",
             headers: %w[Accept Content-Type X-API-KEY],
             methods: %i[get post put delete options],
             max_age: 600 # segons que el navegador pot recordar el preflight
  end
end
