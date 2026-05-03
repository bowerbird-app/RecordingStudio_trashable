class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :application_layout

  before_action :authenticate_user!
  before_action :ensure_demo_access!
  before_action :set_current_actor

  private

  def application_layout
    devise_controller? ? "application" : "flat_pack_sidebar"
  end

  def ensure_demo_access!
    return unless current_user

    workspace_recording = DemoRecordingLookup.workspace_root
    return unless workspace_recording

    access = RecordingStudio::Access.find_or_initialize_by(actor: current_user)
    access.role = :admin
    access.save! if access.new_record? || access.changed?

    RecordingStudio::Recording.with_trashed.find_or_create_by!(
      root_recording_id: workspace_recording.id,
      parent_recording_id: workspace_recording.id,
      recordable: access
    )
  end

  def set_current_actor
    Current.actor = current_user
  end
end
