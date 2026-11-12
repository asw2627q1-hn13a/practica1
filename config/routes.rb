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
end