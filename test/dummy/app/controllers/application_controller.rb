class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  include RecordingStudio::UsesDefaultLayout
  layout :application_layout

  before_action :authenticate_user!
  before_action :set_current_actor

  helper_method :demo_doc_links

  private

  def application_layout
    devise_controller? ? "application" : "recording_studio/default_layout"
  end

  def set_current_actor
    Current.actor = current_user
  end

  def demo_doc_links
    [
      { text: "Overview", url: main_app.showcase_path("overview") },
      { text: "Setup", url: main_app.showcase_path("setup") },
      { text: "Configuration", url: main_app.showcase_path("configuration") },
      { text: "Adding to a recordable", url: main_app.showcase_path("adding-to-a-recordable") },
      { text: "Trash cans", url: main_app.showcase_path("trash-cans") },
      { text: "Trash roots", url: main_app.showcase_path("trash-roots") },
      { text: "Retention", url: main_app.showcase_path("retention") },
      { text: "Events", url: main_app.events_path },
      { text: "Responses", url: main_app.showcase_path("responses") },
      { text: "Methods", url: main_app.showcase_path("methods") }
    ]
  end
end
