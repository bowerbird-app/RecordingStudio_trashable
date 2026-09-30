# frozen_string_literal: true

module RecordingStudioTrashable
  module RetentionPolicy
    class << self
      def normalize_purge_after_days(value)
        stripped = value.to_s.strip
        return nil if stripped.empty?

        Integer(stripped, 10)
      end

      def purge_after_days_for(
        scope_recording,
        recordable_type: nil,
        recording: nil,
        recordings_by_id: nil,
        settings_by_recording_id: nil
      )
        saved_days = configured_retention_days(
          scope_recording,
          recording,
          recordings_by_id,
          settings_by_recording_id
        )
        return saved_days unless saved_days.equal?(:fallback)

        fallback_purge_after_days(recordable_type)
      end

      def settings_by_recording_id(recordings)
        RetentionLookup.settings_by_recording_id(recordings)
      end

      def purge_at(recording:, scope_recording:, recordings_by_id: nil, settings_by_recording_id: nil)
        return if recording.trashed_at.blank?

        purge_after_days = purge_after_days_for(
          scope_recording,
          recordable_type: recording.recordable_type,
          recording: recording,
          recordings_by_id: recordings_by_id,
          settings_by_recording_id: settings_by_recording_id
        )
        return if purge_after_days.blank?

        recording.trashed_at + purge_after_days.days
      end

      def due?(recording:, scope_recording:, as_of: Time.current, recordings_by_id: nil, settings_by_recording_id: nil)
        deadline = purge_at(
          recording: recording,
          scope_recording: scope_recording,
          recordings_by_id: recordings_by_id,
          settings_by_recording_id: settings_by_recording_id
        )
        deadline.present? && deadline <= as_of
      end

      private

      def configured_retention_days(scope_recording, recording, recordings_by_id, settings_by_recording_id)
        return :fallback unless RecordingStudioTrashable.allow_user_retention_settings?

        RetentionLookup.saved_days(
          recording || scope_recording,
          scope_recording,
          recordings_by_id: recordings_by_id,
          settings_by_recording_id: settings_by_recording_id
        )
      end

      def fallback_purge_after_days(recordable_type)
        capability_options = RecordingStudioTrashable.capability_options_for(recordable_type)
        return capability_options[:purge_after_days] if capability_options[:purge_after_days].present?

        RecordingStudioTrashable.configuration.default_purge_after_days
      end
    end
  end

  class RetentionLookup
    class << self
      def saved_days(recording, scope_recording, recordings_by_id:, settings_by_recording_id:)
        current = recording
        visited = {}

        while current
          break if visited_recording?(current, visited)

          saved_days = saved_purge_after_days(current, settings_by_recording_id)
          return saved_days unless saved_days.equal?(:missing)
          break if same_scope?(current, scope_recording)

          current = parent_recording_for(current, recordings_by_id)
        end

        :fallback
      end

      def settings_by_recording_id(recordings)
        ids = recordings.filter_map { |recording| recording.id if recording.is_a?(ActiveRecord::Base) }
        return {} if ids.empty?

        RecordingStudioTrashable::RetentionSetting.where(recording_id: ids).index_by(&:recording_id)
      end

      private

      def saved_purge_after_days(recording, settings_by_recording_id)
        return saved_days_from_index(recording, settings_by_recording_id) if settings_by_recording_id

        setting = RecordingStudioTrashable::RetentionSetting.find_by(recording: recording)
        return :missing unless setting

        setting.purge_after_days
      end

      def saved_days_from_index(recording, settings_by_recording_id)
        recording_id = recording_identifier(recording)
        return :missing if recording_id.nil? || !settings_by_recording_id.key?(recording_id)

        settings_by_recording_id.fetch(recording_id).purge_after_days
      end

      def visited_recording?(recording, visited)
        current_id = recording_identifier(recording)
        return false unless current_id
        return true if visited[current_id]

        visited[current_id] = true
        false
      end

      def parent_recording_for(recording, recordings_by_id)
        return unless recording.respond_to?(:parent_recording_id)

        parent_id = recording.parent_recording_id
        return if parent_id.blank?
        return recordings_by_id[parent_id] if recordings_by_id

        parent_from_database(recording, parent_id)
      end

      def parent_from_database(recording, parent_id)
        recording_model = recording.class
        return unless recording_model.respond_to?(:recording_studio_trashable_including_trashed)

        recording_model.recording_studio_trashable_including_trashed.find_by(id: parent_id)
      end

      def same_scope?(recording, scope_recording)
        recording_id = recording_identifier(recording)
        scope_id = recording_identifier(scope_recording)
        return recording == scope_recording if recording_id.nil? || scope_id.nil?

        recording_id == scope_id
      end

      def recording_identifier(recording)
        return unless recording.respond_to?(:id)

        recording.id
      end
    end
  end
end
