Rails.application.routes.draw do
  devise_for :users

  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioTrashable::Engine, at: "/recording_studio_trashable"

  get "up" => "rails/health#show", as: :rails_health_check
  get "showcase/:slug", to: "showcase#show", as: :showcase

  root "home#index"
end
