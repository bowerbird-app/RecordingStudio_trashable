# frozen_string_literal: true

module RecordingStudioTrashable
  class RetentionPurger
    Result = Struct.new(:purged_recordings, :skipped_recordings, :would_purge_recordings, keyword_init: true)

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      scope_recording: nil,
      actor: nil,
      impersonator: nil,
      as_of: Time.current,
      metadata: {},
      dry_run: false,
      scope_recordings: nil
    )
      @scope_recordings = scope_recordings.nil? ? Array(scope_recording).compact : Array(scope_recordings).compact
      @actor = actor
      @impersonator = impersonator
      @as_of = as_of
      @metadata = metadata.to_h
      @dry_run = dry_run == true
    end
    # rubocop:enable Metrics/ParameterLists

    def purge!
      result = Result.new(purged_recordings: [], skipped_recordings: [], would_purge_recordings: [])
      candidates, skipped = purge_candidates
      result.skipped_recordings.concat(skipped)

      candidates.each { |recording| purge_recording(recording, result) }

      result
    end

    private

    def purge_candidates
      rows = DueRecordings.rows(as_of: @as_of, scope_recordings: @scope_recordings)
      candidates, skipped = rows.partition { |recording| purge_flag(recording, "blocked").zero? }
      [sort_for_purge(candidates), sort_for_purge(skipped)]
    end

    def sort_for_purge(rows)
      rows.sort_by { |recording| [-purge_flag(recording, "depth"), recording.trashed_at.to_f] }
    end

    def purge_flag(recording, name)
      recording.read_attribute("recording_studio_trashable_purge_#{name}").to_i
    end

    def purge_recording(recording, result)
      validate_purge_recording!(recording)

      if @dry_run
        result.would_purge_recordings << recording
        return
      end

      recording.recording_studio_trashable_purge!(**purge_options)
      result.purged_recordings << recording
    rescue RecordingStudioTrashable::PurgeTargetsNotTrashedError
      result.skipped_recordings << recording
    end

    def purge_options
      {
        actor: @actor,
        impersonator: @impersonator,
        metadata: @metadata.merge(source: "recording_studio_trashable_retention")
      }
    end

    def validate_purge_recording!(recording)
      recording.recording_studio_trashable_validate_purge!(actor: @actor)
    end
  end
end
