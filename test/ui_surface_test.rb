# frozen_string_literal: true

require "test_helper"

class UiSurfaceTest < Minitest::Test
  def test_engine_views_use_flatpack_components
    trash_bin_view = File.read(File.expand_path("../app/views/recording_studio_trashable/trash_bins/show.html.erb", __dir__))
    retention_view = File.read(File.expand_path("../app/views/recording_studio_trashable/retention_settings/edit.html.erb", __dir__))

    assert_includes trash_bin_view, "FlatPack::PageTitle::Component"
    assert_includes trash_bin_view, "FlatPack::Card::Component"
    assert_includes trash_bin_view, "FlatPack::Alert::Component"
    assert_includes trash_bin_view, "recording_studio_trashable_page_authorized?(:settings"
    assert_includes trash_bin_view, "recording_studio_trashable_action_authorized?(:restore"
    assert_includes trash_bin_view, "recording_studio_trashable_action_authorized?(:purge"
    assert_includes retention_view, "FlatPack::Button::Component"
  end

  def test_dummy_home_mentions_workspace_and_project_trash_bins
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    source = File.read(view_path)

    assert_includes source, "Workspace trash bin"
    assert_includes source, "Project trash bin"
    assert_includes source, "Pages opt in"
    assert_includes source, "Folders stay active-only"
  end

  def test_showcase_controller_lists_required_pages
    controller_path = File.expand_path("dummy/app/controllers/showcase_controller.rb", __dir__)
    source = File.read(controller_path)

    assert_includes source, '"setup"'
    assert_includes source, '"configuration"'
    assert_includes source, '"adding-to-a-recordable"'
    assert_includes source, '"cascading"'
    assert_includes source, '"methods"'
  end
end
