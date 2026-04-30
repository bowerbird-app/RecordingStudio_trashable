# frozen_string_literal: true

module RecordingStudioTrashable
  class TrashBinsController < ApplicationController
    def show
      @scope_recording = find_recording!(params[:recording_id])
      authorize_mounted_page!(:trash_bin, recording: @scope_recording)
      return if performed?

      @retention_setting = RecordingStudioTrashable.retention_setting_for(@scope_recording)
      @trashed_recordings = RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for(@scope_recording)
    end
  end
end
