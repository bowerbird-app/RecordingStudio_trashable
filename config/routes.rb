# frozen_string_literal: true

RecordingStudioTrashable::Engine.routes.draw do
  root "home#index"

  resources :recordings, only: [] do
    resource :trash_bin, only: :show, controller: :trash_bins
    resource :trash_settings, only: %i[edit update], controller: :retention_settings

    member do
      patch :trash, to: "recordings#trash"
      patch :restore, to: "recordings#restore"
      delete :purge, to: "recordings#purge"
    end
  end
end
