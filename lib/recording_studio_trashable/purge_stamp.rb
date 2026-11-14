# frozen_string_literal: true

module RecordingStudioTrashable
  class PurgeContext
    DEPTH_CAP = 100

    SUBTREE_SQL = <<~SQL.squish.freeze
      WITH RECURSIVE recording_studio_trashable_subtree AS (
        SELECT id, 0 AS depth
        FROM recording_studio_recordings
        WHERE id IN (?)
        UNION ALL
        SELECT child.id, parent.depth + 1
        FROM recording_studio_recordings AS child
        INNER JOIN recording_studio_trashable_subtree AS parent
          ON child.parent_recording_id = parent.id
        WHERE parent.depth < #{DEPTH_CAP}
      )
      SELECT id FROM recording_studio_trashable_subtree
    SQL

    class << self
      def days_by_recording_id(recordings)
        list = Array(recordings).compact
        return {} if list.empty?

        index = ancestor_index(list)
        settings = settings_for(index.values)
        list.to_h { |recording| [recording.id, days_for(recording, index, settings)] }
      end

      def subtree_clause(scope_recordings)
        ids = Array(scope_recordings).filter_map { |scope| scope.respond_to?(:id) ? scope.id : scope }
        return "1=0" if ids.empty?

        "id IN (#{recording_model.sanitize_sql_array([SUBTREE_SQL, ids])})"
      end

      private

      def days_for(recording, index, settings)
        RetentionPolicy.purge_after_days_for(
          root_recording(recording, index),
          recordable_type: recording.recordable_type,
          recording: recording,
          recordings_by_id: index,
          settings_by_recording_id: settings
        ).presence
      end

      def ancestor_index(recordings)
        index = recordings.each_with_object({}) { |recording, found| found[recording.id] = recording if recording.id }
        load_ancestors!(index, parent_ids(recordings, index)) if active_record?(recordings.first)
        index
      end

      def load_ancestors!(index, missing)
        missing = missing.dup
        DEPTH_CAP.times do
          return if missing.empty?

          parents = recording_model.where(id: missing).to_a
          return if parents.empty?

          parents.each { |parent| index[parent.id] = parent }
          missing = parent_ids(parents, index)
        end
      end

      def parent_ids(recordings, index)
        recordings.filter_map(&:parent_recording_id).uniq - index.keys
      end

      def root_recording(recording, index)
        current = recording
        seen = {}
        while climbable?(current, seen)
          seen[current.id] = true
          parent = index[current.parent_recording_id]
          break unless parent

          current = parent
        end
        current
      end

      def climbable?(recording, seen)
        recording&.id && !seen[recording.id] && recording.parent_recording_id.present?
      end

      def settings_for(recordings)
        return {} unless RecordingStudioTrashable.allow_user_retention_settings?
        return {} if recordings.empty? || !active_record?(recordings.first)

        RetentionPolicy.settings_by_recording_id(recordings)
      end

      def active_record?(recording)
        defined?(ActiveRecord::Base) && recording.is_a?(ActiveRecord::Base)
      end

      def recording_model
        RecordingStudio::Recording
      end
    end
  end

  module PurgeStamp
    BATCH_SIZE = 500

    class << self
      def days_by_recording_id(recordings)
        PurgeContext.days_by_recording_id(recordings)
      end

      def deadline(trashed_at, days)
        return if trashed_at.blank? || days.blank?

        trashed_at + days.to_i.days
      end

      def stamp_recordings!(recordings)
        list = trashed_only(recordings)
        return 0 if list.empty?

        days_by_id = days_by_recording_id(list)
        write_groups(list.group_by { |recording| days_by_id[recording.id] })
      end

      def restamp_subtree!(recording)
        return 0 if recording.nil?

        restamp_trashed!(scope_recordings: [recording])
      end

      def restamp_trashed!(scope_recordings: nil, batch_size: BATCH_SIZE)
        relation = recording_model.recording_studio_trashable_trashed
        relation = relation.where(PurgeContext.subtree_clause(scope_recordings)) if scope_recordings
        count = 0
        relation.find_in_batches(batch_size: batch_size) { |batch| count += stamp_recordings!(batch) }
        count
      end

      private

      def trashed_only(recordings)
        Array(recordings).select do |recording|
          recording.respond_to?(:trashed_at) && recording.trashed_at.present?
        end
      end

      def write_groups(groups)
        groups.sum { |days, rows| write_purge_at(rows.map(&:id), days) }
      end

      def write_purge_at(ids, days)
        relation = recording_model.recording_studio_trashable_trashed.where(id: ids)
        return relation.update_all(purge_at: nil) if days.blank?

        relation.update_all(["purge_at = trashed_at + make_interval(days => ?)", days.to_i])
      end

      def recording_model
        RecordingStudio::Recording
      end
    end
  end
end
