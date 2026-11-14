# frozen_string_literal: true

module RecordingStudioTrashable
  # One :trashable answer for Recording.kept. Registration does not connect.
  # A host with no trashed_at column, or no database yet, gets no filter.
  module RecordingFilter
    class << self
      def register!
        RecordingStudio.register_recording_filter(:trashable, sql: method(:kept_sql)) do |recordings|
          kept_relation(recordings)
        end
      end

      def kept_relation(recordings)
        return recordings unless trashed_at_column?

        recordings.where(trashed_at: nil)
      end

      def kept_sql(table)
        return "1=1" unless trashed_at_column?

        "#{table}.trashed_at IS NULL"
      end

      def trashed_at_column?
        return false unless defined?(RecordingStudio::Recording)

        recording = RecordingStudio::Recording
        recording.connection.column_exists?(recording.table_name, :trashed_at)
      rescue ActiveRecord::ActiveRecordError
        false
      end
    end
  end
end
