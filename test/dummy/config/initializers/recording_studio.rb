# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = %w[Workspace Project Folder Page]
  config.actor = -> { Current.actor }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
  config.require_actor = true if config.respond_to?(:require_actor=)
  config.max_metadata_bytes = 16_384 if config.respond_to?(:max_metadata_bytes=)
end
