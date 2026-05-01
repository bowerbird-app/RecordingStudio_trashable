class HomeController < ApplicationController
  def index
    @workspace = Workspace.first
    @workspace_recording = DemoRecordingLookup.workspace_root
    @table_recordings = DemoRecordingLookup.recent_projects(@workspace_recording, limit: 2) +
                        DemoRecordingLookup.recent_active_pages(@workspace_recording, limit: 2) +
                        DemoRecordingLookup.recent_trashed_pages(@workspace_recording, limit: 2)
  end
end
