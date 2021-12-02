require 'sidekiq_unique_jobs/web'

Rails.application.routes.draw do
  namespace :api do
    resources :csv_imports
  end
  mount Sidekiq::Web => '/sidekiq'
end
