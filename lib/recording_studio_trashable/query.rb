# frozen_string_literal: true

# Lightweight entry for sibling gems that need kept/trashed query helpers only.
# Loads RecordingScopes, void_recording!, and installs those helpers on
# RecordingStudio::Recording. Does not load the Rails engine, importmap/assets,
# :trashable capability, CopyHelper, trash metrics, flat_pack, or
# recording_studio_metrics.
#
#   require "recording_studio_trashable/query"
#   RecordingStudio::Recording.recording_studio_trashable_kept_sql("child")

require "recording_studio"
require "recording_studio_trashable/version"
require "recording_studio_trashable/recording_scopes"

module RecordingStudioTrashable
  class << self
    # Soft-void a single recording row without cascade, capability, auth, or
    # trash-bin root marking. Writes through `update_columns` so validations and
    # callbacks do not run (required for Oauth Access grant voids). Prefer
    # `recording_studio_trashable_trash!` when the recordable has Trashable
    # enabled and the caller wants subtree trash + events.
    def void_recording!(recording, time: Time.current)
      raise ArgumentError, "recording is required" if recording.nil?
      return recording if recording.recording_studio_trashable_trashed?

      recording.update_columns(trashed_at: time, updated_at: time)
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
  end
end

RecordingStudioTrashable.register_recording_scopes!

# Query-only hosts have no Trashable engine. Apply now when Recording is already
# loaded. The full gem applies later, after apply_capabilities!.
if !defined?(RecordingStudioTrashable::Engine) && defined?(RecordingStudio::Recording)
  RecordingStudio::Engine.apply_model_extensions!
end
