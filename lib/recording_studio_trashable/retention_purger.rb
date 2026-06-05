# frozen_string_literal: true

module RecordingStudioTrashable
  class RetentionPurger
    Result = Struct.new(:purged_recordings, :skipped_recordings, :would_purge_recordings, keyword_init: true)

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      scope_recording:,
      actor: nil,
      impersonator: nil,
      as_of: Time.current,
      metadata: {},
      dry_run: false
    )
      @scope_recording = scope_recording
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
      recordings = RecordingStudioTrashable::SubtreeQuery.recordings_for(@scope_recording)
      index = recordings.index_by(&:id)
      children_by_parent_id = recordings.group_by(&:parent_recording_id)
      eligible_recordings = recordings.select { |recording| due_recording?(recording) }
      eligible_ids = eligible_recordings.map(&:id)
      candidates, skipped = eligible_recordings.partition do |recording|
        retention_due_subtree?(recording, children_by_parent_id, eligible_ids)
      end

      [
        candidates.sort_by { |recording| [-depth_for(recording, index), recording.trashed_at.to_f] },
        skipped.sort_by { |recording| [-depth_for(recording, index), recording.trashed_at.to_f] }
      ]
    end

    def due_recording?(recording)
      recording.trashed_at.present? &&
        RecordingStudioTrashable::RetentionPolicy.due?(
          recording: recording,
          scope_recording: @scope_recording,
          as_of: @as_of
        )
    end

    def retention_due_subtree?(recording, children_by_parent_id, eligible_ids)
      subtree_for(recording, children_by_parent_id).all? do |target|
        target.trashed_at.present? && eligible_ids.include?(target.id)
      end
    end

    def subtree_for(recording, children_by_parent_id)
      targets = [recording]
      frontier = [recording.id]

      until frontier.empty?
        children = frontier.flat_map { |recording_id| children_by_parent_id.fetch(recording_id, []) }
        targets.concat(children)
        frontier = children.map(&:id)
      end

      targets
    end

    def purge_recording(recording, result)
      validate_purge_recording!(recording)

      if @dry_run
        mark_would_purge(result, recording)
        return
      end

      recording.recording_studio_trashable_purge!(**purge_options)
      result.purged_recordings << recording
    rescue RecordingStudioTrashable::PurgeTargetsNotTrashedError
      result.skipped_recordings << recording
    end

    def mark_would_purge(result, recording)
      result.would_purge_recordings << recording
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

    def depth_for(recording, index)
      depth = 0
      current = recording

      while current.respond_to?(:parent_recording_id) && current.parent_recording_id.present?
        current = index[current.parent_recording_id]
        depth += 1
      end

      depth
    end
  end
end
