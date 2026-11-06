Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Payment results from the providers. The token identifies the account (any host).
  post "webhooks/:provider/:token", to: "webhooks#create", as: :webhook, constraints: { provider: Regexp.union(PaymentProviders.keys) }

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Marketing site and super admin on the apex domain (and www), e.g. domain.com/de
  constraints(AppDomain) do
    get "/", to: "marketing#locale_redirect", as: :marketing_root

    namespace :admin do
      get "login", to: "sessions#new", as: :login
      post "login", to: "sessions#create"
      delete "logout", to: "sessions#destroy", as: :logout
      get "dashboard", to: "dashboard#index", as: :dashboard
      resources :accounts, only: [:index, :show, :update] do
        member do
          post :impersonate
        end
      end
      root to: redirect("/admin/dashboard")
    end

    scope ":locale", locale: Regexp.union(MarketingController::LOCALES) do
      get "/", to: "marketing#index", as: :marketing
      get "signup", to: "signups#new", as: :signup
      post "signup", to: "signups#create", as: nil
      get "signup/check", to: "signups#check", as: :signup_check
      get "login", to: "account_lookups#new", as: :marketing_login
      post "login", to: "account_lookups#create", as: nil
      get "terms", to: "marketing#terms", as: :marketing_terms
      get "impressum", to: "marketing#imprint", as: :marketing_imprint
      get "privacy", to: "marketing#privacy", as: :marketing_privacy
    end
  end

  # Brand images, on account and terminal hosts
  get "brand/:kind", to: "brand_images#show", as: :brand_image, constraints: { kind: Regexp.union(BrandImage::KINDS) }

  # The donation terminal, e.g. terminal1.acme.domain.com
  constraints(TerminalHost) do
    get "/", to: "donations#new", as: :terminal_root
    resources :donations, only: [:create] do
      member do
        get :status
      end
    end
    get "reader_status", to: "donations#reader_status"
  end

  # Account host, e.g. acme.domain.com
  root to: redirect("/dashboard")
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  resources :password_resets, only: [:new, :create, :edit, :update], param: :token
  # Sign-in handover from the signup on the marketing site
  get "session/:token", to: "handovers#show", as: :handover

  get "dashboard", to: "dashboard/overview#show", as: :dashboard
  namespace :dashboard do
    resources :donations, only: [:index]
    resources :terminals, only: [:index, :new, :create, :edit, :update, :destroy]
    resource :appearance, only: [:show, :update], controller: "appearance" do
      delete "images/:kind", action: :remove_image, as: :image
    end
    resources :payment_connections, path: "payments", only: [:index, :edit, :update, :destroy] do
      member do
        post :verify
      end
    end
  end
end
