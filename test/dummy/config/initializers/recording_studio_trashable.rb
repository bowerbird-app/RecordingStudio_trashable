# frozen_string_literal: true

RecordingStudioTrashable.configure do |config|
  config.default_purge_after_days = 30
  config.allow_user_retention_settings = true
  config.authorization_resolver = ->(action:, actor:, **) { action.present? && actor.present? }
end

Rails.application.config.to_prepare do
  RecordingStudio::Recording.class_eval do
    default_scope { where(trashed_at: nil) }

    scope :not_trashed, -> { recording_studio_trashable_active }
    scope :with_trashed, -> { recording_studio_trashable_including_trashed }
  end
end
