Rails.application.routes.draw do
  root "games#index"

  resources :games do
    collection do
      get :refresh_list
    end
    resources :assignments, only: [:create, :destroy]
  end

  resources :officials do
    resources :rules, only: [:create, :update, :destroy]
    resources :official_roles, only: [:create, :destroy]
  end

  resources :assignment_attempts, only: [:index, :show] do
    collection do
      get :refresh_list
    end
    member do
      post :evaluate
    end
  end

  resources :models, only: [:index]

  post "assign_open_games", to: "assignments#assign_open_games"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
