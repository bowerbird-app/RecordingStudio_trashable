class ShowcaseController < ApplicationController
  PAGES = {
    "setup" => {
      title: "Setup",
      body: "Install the addon, copy migrations, migrate, mount the engine, and opt recordables in explicitly."
    },
    "configuration" => {
      title: "Configuration",
      body: "Configure authorization roles, Accessible integration, actor resolvers, and the default retention window in RecordingStudioTrashable.configure."
    },
    "adding-to-a-recordable" => {
      title: "Adding to a recordable",
      body: "Only models that include RecordingStudio::Capabilities::Trashable.to receive the namespaced trash lifecycle on RecordingStudio::Recording."
    },
    "cascading" => {
      title: "Cascading",
      body: "Pass include_children: true to trash, restore, or purge a whole subtree. Purge refuses descendant trees unless you opt into cascading."
    },
    "methods" => {
      title: "Methods",
      body: "Use recording_studio_trashable_trash!, recording_studio_trashable_restore!, and recording_studio_trashable_purge! with actor, impersonator, metadata, and include_children."
    }
  }.freeze

  def show
    @page = PAGES.fetch(params[:slug])
  end
end
