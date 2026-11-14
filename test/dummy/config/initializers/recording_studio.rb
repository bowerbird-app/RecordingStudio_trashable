# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.app_name = "Trashable Demo" if config.respond_to?(:app_name=)
  config.recordable_types = %w[Workspace Project Folder Page]
  config.recordable_types += %w[RecordingStudio::Access] if defined?(RecordingStudioAccessible)
  if defined?(RecordingStudioApi)
    # RecordingStudioApi::AdminApi lists AdminRoot as an allowed parent.
    config.recordable_types += %w[AdminRoot]
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
  # Recording Studio 7 denies record! and create_root_recording! unless an
  # authorizer is set. This dummy grants a write when an actor is present,
  # including a new root where root_recording is nil. Seeds and tests record
  # before access exists. Do not set allow_unauthorized_writes.
  config.authorize_write = ->(actor:, **) { actor.present? }
end
