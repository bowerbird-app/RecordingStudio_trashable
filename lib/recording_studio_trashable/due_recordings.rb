# frozen_string_literal: true

module RecordingStudioTrashable
  # Due rows only. Active recordings stay in the database and are not instantiated.
  # A due row is blocked when any descendant is active, has no `purge_at`, or is not yet due.
  module DueRecordings
    DEPTH_CAP = 100

    SQL = <<~SQL.squish.freeze
      WITH RECURSIVE
      due AS (
        SELECT id, parent_recording_id
        FROM recording_studio_recordings
        WHERE trashed_at IS NOT NULL
          AND purge_at IS NOT NULL
          AND purge_at <= :as_of
      ),
      up AS (
        SELECT due.id AS due_id, due.id AS current_id, due.parent_recording_id, 0 AS depth
        FROM due
        UNION ALL
        SELECT up.due_id, parent.id, parent.parent_recording_id, up.depth + 1
        FROM up
        INNER JOIN recording_studio_recordings AS parent ON parent.id = up.parent_recording_id
        WHERE up.depth < :depth_cap
      ),
      scoped AS (
        SELECT up.due_id, MAX(up.depth) AS depth
        FROM up
        WHERE up.due_id IN (
          SELECT scope_hit.due_id FROM up AS scope_hit WHERE scope_hit.current_id IN (:scope_ids)
        )
        GROUP BY up.due_id
      ),
      blocked AS (
        SELECT due.id
        FROM due
        INNER JOIN scoped ON scoped.due_id = due.id
        INNER JOIN recording_studio_recordings AS child ON child.parent_recording_id = due.id
        WHERE child.trashed_at IS NULL OR child.purge_at IS NULL OR child.purge_at > :as_of
        UNION
        SELECT due.parent_recording_id
        FROM blocked
        INNER JOIN due ON due.id = blocked.id
        INNER JOIN scoped ON scoped.due_id = due.parent_recording_id
        WHERE due.parent_recording_id IS NOT NULL
      )
      SELECT recordings.*,
             scoped.depth AS recording_studio_trashable_purge_depth,
             CASE WHEN blocked.id IS NULL THEN 0 ELSE 1 END AS recording_studio_trashable_purge_blocked
      FROM recording_studio_recordings AS recordings
      INNER JOIN scoped ON scoped.due_id = recordings.id
      LEFT JOIN blocked ON blocked.id = recordings.id
    SQL

    class << self
      def rows(as_of:, scope_recordings:)
        ids = scope_ids(scope_recordings)
        return [] if ids.empty?

        recording_model.find_by_sql([SQL, { as_of: as_of, scope_ids: ids, depth_cap: DEPTH_CAP }])
      end

      private

      def scope_ids(scope_recordings)
        Array(scope_recordings).filter_map do |scope|
          next scope if scope.is_a?(String)
          next unless scope.respond_to?(:id)

          scope.id
        end
      end

      def recording_model
        RecordingStudio::Recording
      end
    end
  end
end
