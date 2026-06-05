# frozen_string_literal: true

module RecordingStudioTrashable
  class RetentionSettingsController < ApplicationController
    def edit
      load_scope_recording
    end

    def update
      load_scope_recording
      return if performed?

      purge_after_days = RecordingStudioTrashable::RetentionPolicy.normalize_purge_after_days(retention_setting_params[:purge_after_days])
      @retention_setting.assign_attributes(purge_after_days: purge_after_days)

      if @retention_setting.save
        redirect_to recording_trash_bin_path(@scope_recording, recording_studio_trashable_back_link_params),
                    notice: "Trash settings updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def load_scope_recording
      @scope_recording = find_recording!(params[:recording_id])
      authorize_mounted_page!(:settings, recording: @scope_recording)
      return if performed?

      unless recording_studio_trashable_retention_settings_enabled?
        redirect_to recording_trash_bin_path(@scope_recording, recording_studio_trashable_back_link_params),
                    alert: "Retention settings are managed by the application."
        return
      end

      @retention_setting = RecordingStudioTrashable.retention_setting_for(@scope_recording)
    end

    def retention_setting_params
      params.fetch(:recording_studio_trashable_retention_setting, {}).permit(:purge_after_days)
    end
  end
end
