Rails.application.routes.draw do
  resources :submissions do
    member do
      get  :delete                 # ACT-02: no-JS delete confirmation page
      post :upvote                 # ACT-03
      post :unvote
      post :favorite               # ACT-05
      post :unfavorite
      post :hide                   # ACT-06
      post :unhide
    end
    # COM-01: add a comment to a submission.
    # COM-02: :new renders the reply form for a given parent comment.
    resources :comments, only: [ :new, :create ]
  end

  # COM-04: a single comment with its subtree (:show).
  # ACT-01/02/04/05: actions on an individual comment.
  resources :comments, only: [ :show, :edit, :update, :destroy ] do
    member do
      get  :delete
      post :upvote
      post :unvote
      post :favorite
      post :unfavorite
    end
  end

  # USR-01 USR-02: view, edit and update user profiles
  resources :users, only: [ :show, :edit, :update ] do
    # USR-07: public activity listings of a user's profile. (The user's comments
    # are shown by the existing threads page: /threads?id=<user id>.)
    member do
      get :submissions            # opens the "<user>'s submissions" tab
      get :favorite_submissions   # "favorites" tab, default sub-view
      get :favorite_comments      # "favorites" tab, comments sub-view
    end
  end

  # News page (SUB-01): the app root, shows url submissions ranked by points.
  get "news", to: "submissions#index", as: :news
  # SRC-01: search all visible submissions by title.
  get "search", to: "submissions#search", as: :search
  # SUB-02 pages.
  get "submit", to: "submissions#new", as: :submit
  get "newest", to: "submissions#newest", as: :newest
  get "ask", to: "submissions#ask", as: :ask
  # LST-02 / LST-03 listing pages.
  get "threads", to: "comments#threads", as: :threads
  get "comments", to: "comments#index", as: :comments
  # ACT-06: the logged-in user's hidden submissions.
  get "hidden", to: "submissions#hidden", as: :hidden
  # USR-08: the logged-in user's upvoted submissions and comments.
  get "upvoted", to: "users#upvoted_submissions", as: :upvoted
  get "upvoted/comments", to: "users#upvoted_comments", as: :upvoted_comments
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "submissions#index"
  
  get "/login", to: "sessions#new", as: :login
  # GitHub OAuth
  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  
  delete "/logout", to: "sessions#destroy", as: :logout

  # REST-01: API REST de nivell 2 (JSON). El disseny complet (recursos, URIs,
  # verbs, codis d'estat i format d'error) és a docs/api-design.md: qualsevol
  # canvi en aquestes rutes s'ha d'actualitzar també allà i a api/api.yaml.
  # Els controladors es creen a mesura que s'implementen les històries API-xx
  # (una ruta ja definida però sense controlador encara no és utilitzable).
  # Les rutes que no existeixen sota /api responen amb un 404 en JSON (vegeu el final).
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # Un usuari té com a molt un vot / un favorit per element, de manera que
      # l'element (submission o comment) i l'api-key identifiquen el recurs.
      # POST crea, DELETE esborra; el controlador mira si arriba :submission_id
      # o :comment_id.
      concern :votable do
        resource :votes, only: %i[create destroy]
      end
      concern :favoritable do
        resource :favorites, only: %i[create destroy]
      end

      # API-03..06: submissions (llistats news/newest/ask i cerca amb ?list= i ?q=)
      resources :submissions, only: %i[index show create update destroy],
                              concerns: %i[votable favoritable] do
        resources :comments, only: :create                                    # API-07
        resource :hidden, only: %i[create destroy], controller: "hidden"      # API-13
      end

      # API-07..10: comments (llistat global, subarbre, edició, replies)
      resources :comments, only: %i[index show update destroy],
                            concerns: %i[votable favoritable] do
        resources :replies, only: :create                                     # API-07
      end

      # API-14..17: usuaris i la seva activitat
      resources :users, only: %i[show update] do
        member do
          get "submissions"
          get "comments"
          get "threads"
          get "hidden"
          get "favorites/submissions", action: :favorite_submissions
          get "favorites/comments",    action: :favorite_comments
          get "upvoted/submissions",   action: :upvoted_submissions
          get "upvoted/comments",      action: :upvoted_comments
          put "images",                action: :update_images                 # multipart/form-data
          delete "images/:kind",       action: :destroy_image                 # kind = avatar | banner
        end
      end
    end

    # Tot el prefix /api és reservat a l'API: qualsevol ruta que no existeixi
    # (/api/v1/foo, /api/v2/..., /api/foo, o un verb no definit com
    # DELETE /api/v1/submissions) respon 404 en JSON, no la pàgina HTML d'error.
    # Ha de ser l'última ruta del namespace.
    match "*path", to: "v1/not_found#show", via: :all, format: false
  end
end