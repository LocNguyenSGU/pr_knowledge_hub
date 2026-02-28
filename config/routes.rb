Rails.application.routes.draw do
  devise_for :users
  # Root path
  root "dashboard#index"

  # Pull Requests
  resources :pull_requests, only: [ :index, :show ] do
    collection do
      get :stats
    end
  end

  # AI Insights
  resources :insights, only: [ :index, :show ]

  # Search
  get "search", to: "search#index"

  # Sync (manual trigger)
  namespace :sync do
    post :pull_requests, controller: :base
    post :comments, controller: :base
    post :analyze, controller: :base
    get :status, controller: :base
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI (protected by authentication)
  require "sidekiq/web"
  require "sidekiq/cron/web"

  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end
end
