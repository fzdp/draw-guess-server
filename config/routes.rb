Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  namespace :v1, defaults: {format: :json} do
    resources :rooms, only: [:index, :create, :show, :update] do
      member do
        post :auth
      end
    end

    resources :users, only: [:create] do
      collection do
        post :login
        post :update_name
        get :get_profile
        post :send_sign_up_email
        post :send_reset_password_email
        post :reset_password
      end
    end

    resources :score_records, only: [:index] do
    end
  end
end
