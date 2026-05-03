# frozen_string_literal: true

module RecordingStudioTrashable
  class RecordingsController < ApplicationController
    rescue_from ActiveRecord::RecordInvalid, ArgumentError, RecordingStudio::CapabilityDisabled do |error|
      respond_with_lifecycle_error(error.message)
    end

    def trash
      update_recording!(
        :trash,
        :recording_studio_trashable_trash!,
        success_message: -> { "#{recording_studio_trashable_recording_label(@recording)} moved to trash" }
      )
    end

    def restore
      update_recording!(
        :restore,
        :recording_studio_trashable_restore!,
        success_message: -> { "#{recording_studio_trashable_recording_label(@recording)} restored" }
      )
    end

    def purge
      update_recording!(
        :purge,
        :recording_studio_trashable_purge!,
        success_message: -> { "#{recording_studio_trashable_recording_label(@recording)} permantly deleted" }
      )
    end

    private

    def update_recording!(action, method_name, success_message:)
      @recording = find_recording!(params[:id])
      authorize_recording_action!(action, recording: @recording)
      return if performed?

      update_recording_lifecycle!(method_name)
      resolved_success_message = success_message.respond_to?(:call) ? instance_exec(&success_message) : success_message
      respond_with_lifecycle_success(resolved_success_message)
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
        metadata: lifecycle_metadata
      )
    end

    def respond_with_lifecycle_success(message)
      return render json: { ok: true, notice: message } if async_response?

      redirect_to sync_redirect_path, notice: message
    end

    def respond_with_lifecycle_error(message)
      return render json: { ok: false, alert: message }, status: :unprocessable_entity if async_response?

      redirect_to sync_redirect_path, alert: message
    end

    def async_response?
      request.format.json? || boolean_param(params[:async]) || params[:redirect_target].to_s == "async"
    end

    def sync_redirect_path
      recording_studio_trashable_back_path(fallback: fallback_redirect_path)
    end

    def fallback_redirect_path
      scope_id = params[:return_to_recording_id].presence || params[:recording_id].presence || fallback_scope_id
      return root_path if scope_id.blank?

      recording_trash_bin_path(scope_id, recording_studio_trashable_back_link_params)
    end

    def fallback_scope_id
      return unless @recording

      @recording.root_recording_id.presence || @recording.id
    end
  end
end
