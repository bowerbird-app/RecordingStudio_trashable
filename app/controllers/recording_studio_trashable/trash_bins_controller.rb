# frozen_string_literal: true

module RecordingStudioTrashable
  class TrashBinsController < ApplicationController
    PAGE_SIZE = 25

    def show
      @scope_recording = find_recording!(params[:recording_id])
      authorize_mounted_page!(:trash_bin, recording: @scope_recording)
      return if performed?

      @retention_setting = RecordingStudioTrashable.retention_setting_for(@scope_recording)
      @search_query = params[:q].to_s.strip
      trashed_recordings = RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(
        @scope_recording,
        query: @search_query
      ).reorder(trashed_at: :desc, id: :desc)

      @pagy, @trashed_recordings = pagy(trashed_recordings, limit: PAGE_SIZE)
    end
  end
end
