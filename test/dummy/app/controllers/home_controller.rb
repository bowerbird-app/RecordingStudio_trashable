class HomeController < ApplicationController
  def index
    @workspace = Workspace.first
    @workspace_recording = DemoRecordingLookup.workspace_root
    @project_recording = DemoRecordingLookup.by_slug(type: "Project", slug: "album-launch")
    @active_page_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "mix-notes")
    @trashed_page_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "archived-lyrics")
    @folder_recording = DemoRecordingLookup.by_slug(type: "Folder", slug: "reference-assets")
  end
end
