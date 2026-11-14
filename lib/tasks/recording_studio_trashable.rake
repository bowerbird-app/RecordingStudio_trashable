# frozen_string_literal: true

require "time"
require "active_model"

unless defined?(RecordingStudioTrashableRake)
  module RecordingStudioTrashableRake
    module_function

    def scope_ids
      ENV.fetch("SCOPE_RECORDING_IDS", "").split(",").map(&:strip).reject(&:empty?)
    end

    def purge_due
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil)) == true
      result = RecordingStudioTrashable::RetentionPurgeJob.perform_now(
        scope_recording_ids: scope_ids.presence,
        as_of: parsed_as_of,
        metadata: { source: ENV["SOURCE"].presence || "recording_studio_trashable_retention_task" },
        dry_run: dry_run
      )
      puts(RecordingStudioTrashable.purge_summary_message(result, dry_run: dry_run))
    end

    def parsed_as_of
      as_of_value = ENV.fetch("AS_OF", nil)
      return Time.current if as_of_value.to_s.strip.empty?

      Time.zone&.parse(as_of_value) || Time.iso8601(as_of_value)
    end

    def restamp_purge_at
      ids = scope_ids
      scopes = ids.empty? ? nil : scope_recordings(ids)
      count = RecordingStudioTrashable::PurgeStamp.restamp_trashed!(scope_recordings: scopes)
      puts "Restamped purge_at on #{count} trashed recordings."
    end

    def scope_recordings(ids)
      RecordingStudio::Recording.where(id: ids).to_a
    end
  end
end

namespace :recording_studio_trashable do
  desc "Purge trashed recordings whose retention window has expired"
  task purge_due: :environment do
    RecordingStudioTrashableRake.purge_due
  end

  desc "Recompute purge_at for trashed recordings. Optional SCOPE_RECORDING_IDS limits the subtrees."
  task restamp_purge_at: :environment do
    RecordingStudioTrashableRake.restamp_purge_at
  end
end
