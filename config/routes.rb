# frozen_string_literal: true

Rails.application.routes.draw do
  root 'stores#welcome'
  get 'auth/shopify/callback', to: 'stores#callback'
  get 'stores/welcome', to: 'stores#welcome'
  get 'stores/create_permission', to: 'stores#create_permission'
  get 'stores/download_csv', to: 'stores#download_csv', format: :csv
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
