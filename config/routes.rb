# frozen_string_literal: true

RecordingStudioTrashable::Engine.routes.draw do
  root "home#index"

  resources :recordings, only: [] do
    resource :trash_bin, only: :show, controller: :trash_bins
    resource :retention_setting, only: %i[edit update]

    member do
      patch :trash, to: "recordings#trash"
      patch :restore, to: "recordings#restore"
      delete :purge, to: "recordings#purge"
    end
  end
end
