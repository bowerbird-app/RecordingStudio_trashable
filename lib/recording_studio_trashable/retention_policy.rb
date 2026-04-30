# frozen_string_literal: true

module RecordingStudioTrashable
  module RetentionPolicy
    class << self
      def normalize_purge_after_days(value)
        stripped = value.to_s.strip
        return nil if stripped.empty?

        Integer(stripped, 10)
      rescue ArgumentError, TypeError
        nil
      end

      def purge_after_days_for(scope_recording)
        setting = scope_recording && RecordingStudioTrashable::RetentionSetting.find_by(recording: scope_recording)
        setting&.purge_after_days || RecordingStudioTrashable.configuration.default_purge_after_days
      end

      def purge_at(recording:, scope_recording:)
        return if recording.trashed_at.blank?

        purge_after_days = purge_after_days_for(scope_recording)
        return if purge_after_days.blank?

        recording.trashed_at + purge_after_days.days
      end

      def due?(recording:, scope_recording:, as_of: Time.current)
        deadline = purge_at(recording: recording, scope_recording: scope_recording)
        deadline.present? && deadline <= as_of
      end
    end
  end
end
