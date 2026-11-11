# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api_docs'
  mount Rswag::Api::Engine => '/api_docs'

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      scope :auth, controller: :auth do
        post 'login'
        post 'verify_2fa'
        patch 'activate'
        patch 'verify'

        scope 'password', as: :password do
          post 'reset', action: :request_reset
          patch 'reset', action: :confirm_reset
        end

        post 'request_2fa_code_resend'
        post 'request_activation_code_resend'
        post 'request_verification_code_resend'
        post 'request_reset_code_resend'

        post 'blacklist_user'
        post 'whitelist_user'
      end

      post 'stripe_payments_webhook/handle', to: 'stripe_payments_webhook#handle'
      post 'n8n_webhook/handle', to: 'n8n_webhook#handle'

      resources :users, controller: :users, only: %i[create index show update destroy] do
        collection do
          get 'me'
          post 'logout'
        end

        member do
          get 'actions'
          patch 'role/update', to: 'users#role'
          patch 'update_location'
          patch 'update_details'
          patch 'update_entrepreneur_details'
        end
      end

      resources :categories, controller: :products, only: [] do
        collection do
          get '/', action: :available_categories
          post '/', action: :create_category
        end

        member do
          patch '/', action: :update_category
          delete '/', action: :destroy_category
        end
      end

      resources :products, controller: :products, only: %i[index create show update destroy] do
        member do
          post 'like'
          post 'rate'
          post 'comment'
          post 'create_photo'
        end
      end

      resources :payments, controller: :payments, only: %i[index create show]

      resources :invoices, controller: :invoices, only: %i[index show] do
        collection do
          get 'me'
        end

        member do
          get 'download'
        end
      end

      resources :orders, controller: :orders, only: %i[index create show update destroy] do
        collection do
          get 'me'
        end

        member do
          post 'cancel'
          patch 'status', to: 'orders#mark_order_status'
          patch 'payment_status', to: 'orders#mark_payment_status'
          post 'products', to: 'orders#add_product'
          delete 'products/:product_id', to: 'orders#remove_product', as: :remove_product
        end

        resources :refunds, controller: :refunds, only: %i[index create]
      end

      resources :refunds, controller: :refunds, only: %i[show update destroy] do
        collection do
          get 'me'
        end

        member do
          post 'cancel'
          post 'complete'
        end
      end

      resource :cart, controller: :cart, only: [:show] do
        member do
          post 'add/:product_id', to: 'cart#add', as: :add_to
          delete 'revoke/:item_id', to: 'cart#revoke', as: :revoke_from
          delete 'clear'
        end
      end

      scope :diagnostics, controller: :diagnostics do
        get 'readiness', to: 'diagnostics#readiness'
        get 'health', to: 'diagnostics#health'
        get 'metrics', to: 'diagnostics#metrics'
      end
    end
  end
end
