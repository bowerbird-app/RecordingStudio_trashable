# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.app_name = "Trashable Demo" if config.respond_to?(:app_name=)
  config.recordable_types = %w[Workspace Project Folder Page]
  config.recordable_types += %w[RecordingStudio::Access] if defined?(RecordingStudioAccessible)
  if defined?(RecordingStudioApi)
    config.recordable_types += %w[
      RecordingStudioApi::ApiClient
      RecordingStudioApi::ApiCredential
      RecordingStudioApi::ApiAccessToken
      RecordingStudioApi::AdminApi
    ]
  end
  config.actor = -> { Current.actor }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
  config.require_actor = true if config.respond_to?(:require_actor=)
  config.max_metadata_bytes = 16_384 if config.respond_to?(:max_metadata_bytes=)
end
