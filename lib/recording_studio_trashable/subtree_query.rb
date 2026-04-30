# frozen_string_literal: true

module RecordingStudioTrashable
  module SubtreeQuery
    EPOCH_FALLBACK = Time.at(0).freeze

    class << self
      def recordings_for(root_recording, include_root: true)
        return [] unless root_recording

        recordings = include_root ? [root_recording] : []
        frontier = [root_recording.id]

        until frontier.empty?
          children = RecordingStudio::Recording.recording_studio_trashable_including_trashed
                                              .where(parent_recording_id: frontier)
                                              .reorder(created_at: :asc)
                                              .to_a
          recordings.concat(children)
          frontier = children.map(&:id)
        end

        recordings
      end

      def trashed_recordings_for(root_recording)
        recordings_for(root_recording)
          .select { |recording| recording.trashed_at.present? }
          .sort_by { |recording| [-(recording.trashed_at || EPOCH_FALLBACK).to_f, -(recording.updated_at || EPOCH_FALLBACK).to_f] }
      end
    end
  end
end
