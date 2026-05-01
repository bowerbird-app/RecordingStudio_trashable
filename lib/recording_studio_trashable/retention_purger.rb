# frozen_string_literal: true

module RecordingStudioTrashable
  class RetentionPurger
    Result = Struct.new(:purged_recordings, :skipped_recordings, keyword_init: true)

    def initialize(scope_recording:, actor: nil, impersonator: nil, as_of: Time.current, metadata: {})
      @scope_recording = scope_recording
      @actor = actor
      @impersonator = impersonator
      @as_of = as_of
      @metadata = metadata.to_h
    end

    def purge!
      result = Result.new(purged_recordings: [], skipped_recordings: [])

      due_recordings.each { |recording| purge_recording(recording, result) }

      result
    end

    private

    def due_recordings
      recordings = RecordingStudioTrashable::SubtreeQuery.recordings_for(@scope_recording)
      index = recordings.index_by(&:id)
      eligible_recordings = recordings.select { |recording| due_recording?(recording) }

      eligible_recordings.sort_by { |recording| [-depth_for(recording, index), recording.trashed_at.to_f] }
    end

    def due_recording?(recording)
      recording.trashed_at.present? &&
        RecordingStudioTrashable::RetentionPolicy.due?(
          recording: recording,
          scope_recording: @scope_recording,
          as_of: @as_of
        )
    end

    def purge_recording(recording, result)
      recording.recording_studio_trashable_purge!(
        actor: @actor,
        impersonator: @impersonator,
        include_children: false,
        metadata: @metadata.merge(source: "recording_studio_trashable_retention")
      )
      result.purged_recordings << recording
    rescue ArgumentError => e
      raise unless skippable_purge_error?(e)

      result.skipped_recordings << recording
    end

    def depth_for(recording, index)
      depth = 0
      current = recording

      while current.respond_to?(:parent_recording_id) && current.parent_recording_id.present?
        current = index[current.parent_recording_id]
        depth += 1
      end

      depth
    end

    def skippable_purge_error?(error)
      error.message.include?("include_children: true") ||
        error.message.include?("already be trashed")
    end
  end
end
