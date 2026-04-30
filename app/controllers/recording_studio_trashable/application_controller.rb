# frozen_string_literal: true

module RecordingStudioTrashable
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :exception

    helper_method :recording_studio_trashable_recording_label,
                  :recording_studio_trashable_retention_label,
                  :recording_studio_trashable_action_authorized?,
                  :recording_studio_trashable_page_authorized?

    private

    def current_trashable_actor
      RecordingStudioTrashable.current_actor(controller: self)
    end

    def current_trashable_impersonator
      RecordingStudioTrashable.current_impersonator(controller: self)
    end

    def find_recording!(recording_id)
      RecordingStudio::Recording.recording_studio_trashable_including_trashed.find(recording_id)
    end

    def authorize_mounted_page!(action, recording: nil)
      return true if recording_studio_trashable_page_authorized?(action, recording: recording)

      redirect_back fallback_location: root_path,
                    alert: "You are not authorized to manage trash here."
      false
    end

    def recording_studio_trashable_action_authorized?(action, recording)
      RecordingStudioTrashable.authorized?(
        action: action,
        actor: current_trashable_actor,
        recording: recording,
        controller: self
      )
    end

    def recording_studio_trashable_page_authorized?(action, recording: nil)
      RecordingStudioTrashable.mounted_page_authorized?(
        action: action,
        actor: current_trashable_actor,
        recording: recording,
        controller: self
      )
    end

    def recording_studio_trashable_recording_label(recording)
      recordable = recording.recordable
      return recordable.title if recordable.respond_to?(:title) && recordable.title.present?
      return recordable.name if recordable.respond_to?(:name) && recordable.name.present?

      "#{recording.recordable_type} ##{recording.id.to_s.first(8)}"
    end

    def recording_studio_trashable_retention_label(recording, scope_recording)
      purge_at = RecordingStudioTrashable::RetentionPolicy.purge_at(recording: recording, scope_recording: scope_recording)
      return "No automatic purge window" if purge_at.blank?

      RecordingStudioTrashable::RetentionPolicy.due?(recording: recording, scope_recording: scope_recording) ? "Due now" : "Purges #{helpers.l(purge_at, format: :long)}"
    end

    def boolean_param(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
