Rails.application.routes.draw do
  # Devise routes for API authentication
  # Note: Devise 4.9.4 generates deprecation warnings about hash arguments in Rails 8.1+
  # This is an internal Devise issue that will be fixed in a future release.
  # See: https://github.com/heartcombo/devise/issues/5605
  devise_for :users,
             path: "api/v1/auth",
             path_names: { sign_in: "login", sign_out: "logout", registration: "register" },
             controllers: { sessions: "api/v1/auth/sessions", registrations: "api/v1/auth/registrations" }

  # API routes
  namespace :api do
    namespace :v1 do
      namespace :auth do
        # Current user profile
        get "me", to: "/api/v1/users#me"
        patch "me", to: "/api/v1/users#update_me"
      end

      # Worker profiles
      resources :workers, controller: 'worker_profiles', only: [:create, :index] do
        collection do
          get 'me', to: 'worker_profiles#show'
          patch 'me', to: 'worker_profiles#update'
        end
      end

      # Employer profiles
      resources :employers, controller: 'employer_profiles', only: [:create] do
        collection do
          get 'me', to: 'employer_profiles#show'
          patch 'me', to: 'employer_profiles#update'
          get 'me/onboarding_status', to: 'employer_profiles#onboarding_status'
        end
      end

      # Companies
      resources :companies, only: [:index, :show, :create, :update]

      # Work locations
      resources :work_locations, only: [:index, :show, :create, :update, :destroy]

      # Shifts
      resources :shifts, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get 'lookup/:tracking_code', to: 'shifts#lookup', as: :lookup
        end
        member do
          post :start_recruiting
          post :cancel
        end
        resources :recruiting_activity_logs, only: [:index]
      end

      # Shift assignments
      resources :shift_assignments, only: [:index, :show] do
        member do
          post :accept
          post :decline
          post :check_in
          post :check_out
          post :cancel
          post :approve_timesheet
        end
      end

      # Activities (recent activity feed)
      resources :activities, only: [:index]

      # Admin namespace
      namespace :admin do
        resources :recruiting, only: [:index, :show], param: :shift_id

        resources :feature_flags, only: [:index, :show, :create, :update] do
          member do
            post :toggle
            post :archive
            post :restore
          end
        end
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
