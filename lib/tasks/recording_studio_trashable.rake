# frozen_string_literal: true

require "time"

namespace :recording_studio_trashable do
  desc "Purge trashed recordings whose retention window has expired"
  task purge_due: :environment do
    scope_recording_ids = ENV.fetch("SCOPE_RECORDING_IDS", "").split(",").map(&:strip).reject(&:empty?)
    as_of_value = ENV.fetch("AS_OF", nil)
    as_of = if as_of_value.to_s.strip.empty?
              Time.current
            else
              Time.zone&.parse(as_of_value) || Time.iso8601(as_of_value)
            end

    result = RecordingStudioTrashable::RetentionPurgeJob.perform_now(
      scope_recording_ids: scope_recording_ids.presence,
      as_of: as_of,
      metadata: { source: ENV["SOURCE"].presence || "recording_studio_trashable_retention_task" }
    )

    puts(
      "Purged #{result.purged_recordings.size} recordings, skipped " \
      "#{result.skipped_recordings.size} across #{result.scope_recordings.size} scopes"
    )
  end
end
