class HomeController < ApplicationController
  def index
    load_home_demo_state
    @table_recordings = DemoRecordingLookup.recent_projects(@workspace_recording, limit: 2) +
                        DemoRecordingLookup.recent_active_pages(@workspace_recording, limit: 2) +
                        DemoRecordingLookup.recent_trash_roots(@workspace_recording, limit: 2)
  end

  def purge_due
    load_home_demo_state

    unless @workspace_recording
      redirect_to root_path, alert: "No workspace recording is available for retention purging."
      return
    end

    unless @can_purge_due
      redirect_to root_path, alert: "You are not authorized to purge due trash."
      return
    end

    result = RecordingStudioTrashable.purge_due_recordings_for_all_scopes(
      scope_recordings: [ @workspace_recording ],
      actor: current_user,
      as_of: Time.current,
      metadata: { source: "dummy_home_manual_purge" }
    )

    redirect_to(
      root_path,
      notice: RecordingStudioTrashable.purge_summary_message(result)
    )
  end

  private

  def load_home_demo_state
    @workspace = Workspace.first
    @workspace_recording = DemoRecordingLookup.workspace_root
    @can_purge_due = @workspace_recording.present? && RecordingStudioTrashable.authorized?(
      action: :purge,
      actor: current_user,
      recording: @workspace_recording,
      controller: self
    )
  end
end
