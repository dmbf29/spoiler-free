Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Spoiler-safe highlight feed. Supports ?sport=<slug> and ?competition=<slug>.
      resources :videos, only: %i[index]
      # Sports (with their active competitions nested) for the filter UI.
      resources :sports, only: %i[index]
      # YouTube WebSub push callback (hub verification + notifications).
      get "youtube/webhook", to: "youtube_webhooks#verify"
      post "youtube/webhook", to: "youtube_webhooks#receive"
    end
  end
end
