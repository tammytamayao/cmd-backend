Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      resources :subscribers, only: [ :index, :show ]
      resources :sessions, only: [ :create, :destroy ]
      get "session/me", to: "sessions#show"
      resources :billings, only: [ :index ]
      resources :payments, only: [ :index, :create ] do
        member do
          get :receipt_url
        end
      end

      # S3 file management routes
      scope :s3 do
        get "health", to: "s3#health"
        get "debug", to: "s3#debug"
        resources :files, controller: "s3", only: [ :index, :show, :create, :destroy ] do
          member do
            get :download
          end
        end
        scope :debug do
          get "files/:id/download", to: "s3#debug_download"
        end
      end
    end

    # Admin endpoints (currently unauthenticated for debugging)
    # TODO: Implement proper authentication for admin endpoints in production
    namespace :admin do
      resources :payments, only: [ :index, :create, :show ]
    end
  end
end
