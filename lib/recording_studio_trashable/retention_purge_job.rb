# frozen_string_literal: true

require "active_job"

module RecordingStudioTrashable
  class RetentionPurgeJob < ActiveJob::Base
    queue_as :default

    def perform(scope_recording_ids: nil, as_of: nil, metadata: {})
      RecordingStudioTrashable.purge_due_recordings_for_all_scopes(
        scope_recordings: scope_recordings(scope_recording_ids),
        as_of: as_of || Time.current,
        metadata: { source: "recording_studio_trashable_retention_job" }.merge(metadata.to_h)
      )
    end

    private

    def scope_recordings(scope_recording_ids)
      return RecordingStudioTrashable.root_scope_recordings if scope_recording_ids.blank?

      RecordingStudio::Recording
        .recording_studio_trashable_including_trashed
        .where(id: Array(scope_recording_ids))
        .reorder(created_at: :asc)
        .to_a
    end
  end
end
