# frozen_string_literal: true

# Lightweight entry for sibling gems that need trash scopes and void_recording!.
# Loads RecordingScopes and installs them on RecordingStudio::Recording.
# Does not load the Rails engine, importmap/assets, :trashable capability,
# CopyHelper, trash metrics, flat_pack, or recording_studio_metrics.
#
# The full engine registers the :trashable recording filter from an initializer.
# This file registers it when the engine is not loaded, or when the app has
# already finished booting.
#
#   require "recording_studio_trashable/query"
#   RecordingStudio.kept_sql("child")

require "recording_studio"
require "recording_studio_trashable/version"
require "recording_studio_trashable/recording_scopes"
require "recording_studio_trashable/recording_filter"

module RecordingStudioTrashable
  class << self
    # Sets trashed_at through update_columns on this recording and its descendants.
    # Skips validations, callbacks, capability checks, authorization, events,
    # trash_root, and purge_at. Rows that are already trashed stay as they are.
    # Use recording_studio_trashable_trash! for user-facing subtree trash.
    def void_recording!(recording, time: Time.current)
      raise ArgumentError, "recording is required" if recording.nil?

      void_targets(recording).each do |target|
        next if target.recording_studio_trashable_trashed?

        target.update_columns(trashed_at: time, updated_at: time)
      end
      recording
    end

    # One proc for the life of the process. A second registration is a new
    # object id, and core applies every one.
    def register_recording_scopes!
      @recording_scope_extension ||= proc { include RecordingStudioTrashable::RecordingScopes }
      extensions = RecordingStudio.configuration.hooks.model_extensions_for(:recording)
      return if extensions.include?(@recording_scope_extension)

      RecordingStudio.configuration.hooks.extend_model(:recording, &@recording_scope_extension)
    end

    private

    def void_targets(recording)
      descendants = recording.respond_to?(:descendants) ? recording.descendants : []
      [recording, *Array(descendants)]
    end
  end
end

RecordingStudioTrashable.register_recording_scopes!

# Query-only hosts have no Trashable engine. Apply now when Recording is already
# loaded. The full gem applies later, after apply_capabilities!.
if !defined?(RecordingStudioTrashable::Engine) && defined?(RecordingStudio::Recording)
  RecordingStudio::Engine.apply_model_extensions!
end

if !defined?(RecordingStudioTrashable::Engine) ||
   (defined?(Rails::Application) && Rails.application.respond_to?(:initialized?) && Rails.application.initialized?)
  RecordingStudioTrashable::RecordingFilter.register!
end
