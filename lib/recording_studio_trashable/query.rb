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

    def install_query_helpers!
      return unless defined?(RecordingStudio::Recording)
      return if RecordingStudio::Recording.included_modules.include?(RecordingScopes)

      RecordingStudio::Recording.include(RecordingScopes)
    end
  end
end

RecordingStudioTrashable.install_query_helpers!
