Rails.application.routes.draw do
  resources :submissions do
    # COM-01: add a comment to a submission.
    # COM-02: :new renders the reply form for a given parent comment.
    resources :comments, only: [ :new, :create ]
  end
  resources :users

  # News page (SUB-01): the app root, shows url submissions ranked by points.
  get "news", to: "submissions#index", as: :news
  # SUB-02 pages.
  get "submit", to: "submissions#new", as: :submit
  get "newest", to: "submissions#newest", as: :newest
  get "ask", to: "submissions#ask", as: :ask
  # LST-02 / LST-03 listing pages.
  get "threads", to: "comments#threads", as: :threads
  get "comments", to: "comments#index", as: :comments
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
end
