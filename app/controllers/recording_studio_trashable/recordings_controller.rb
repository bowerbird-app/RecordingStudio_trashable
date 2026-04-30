# frozen_string_literal: true

module RecordingStudioTrashable
  class RecordingsController < ApplicationController
    rescue_from ActiveRecord::RecordInvalid, ArgumentError, RecordingStudio::CapabilityDisabled do |error|
      redirect_to fallback_redirect_path, alert: error.message
    end

    def trash
      update_recording!(:trash, :recording_studio_trashable_trash!, success_message: "Recording moved to trash.")
    end

    def restore
      update_recording!(:restore, :recording_studio_trashable_restore!, success_message: "Recording restored.")
    end

    def purge
      update_recording!(:purge, :recording_studio_trashable_purge!, success_message: "Recording permanently purged.")
    end

    private

    def update_recording!(action, method_name, success_message:)
      @recording = find_recording!(params[:id])
      authorize_mounted_page!(action, recording: @recording)
      return if performed?

      update_recording_lifecycle!(method_name)
      redirect_to fallback_redirect_path, notice: success_message
    end

    def include_children_param
      return unless params.key?(:include_children)

      boolean_param(params[:include_children])
    end

    def lifecycle_metadata
      raw_metadata = params[:metadata]
      metadata = raw_metadata.respond_to?(:permit!) ? raw_metadata.permit!.to_h : {}

      { source: "recording_studio_trashable_ui" }.merge(metadata)
    end

    def update_recording_lifecycle!(method_name)
      @recording.public_send(
        method_name,
        actor: current_trashable_actor,
        impersonator: current_trashable_impersonator,
        metadata: lifecycle_metadata,
        include_children: include_children_param
      )
    end

    def fallback_redirect_path
      scope_id = params[:return_to_recording_id].presence || params[:recording_id].presence
      return root_path if scope_id.blank?

      recording_trash_bin_path(scope_id)
    end
  end
end
