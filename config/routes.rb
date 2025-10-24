Rails.application.routes.draw do
  get 'donations/create'
  get 'donations/status'
  get 'home/index'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "home#index"
  post 'sumup/checkout_return_url', to: 'sumup#checkout_return_url'

   resources :donations, only: [:create] do
    member do
      get :status
    end
  end
  
  get 'reader_status', to: 'donations#reader_status'
end
