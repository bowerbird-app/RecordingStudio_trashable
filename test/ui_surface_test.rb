# frozen_string_literal: true

require "test_helper"

class UiSurfaceTest < Minitest::Test
  def test_engine_views_use_flatpack_components
    home_view = read_repo_file("../app/views/recording_studio_trashable/home/index.html.erb")
    trash_bin_view = read_repo_file("../app/views/recording_studio_trashable/trash_bins/show.html.erb")
    retention_view = read_repo_file("../app/views/recording_studio_trashable/retention_settings/edit.html.erb")

    assert_includes home_view, "aria-label=\"Breadcrumb\""
    assert_includes home_view, 'icon: "arrow-left"'
    refute_includes home_view, 'text: "Capabilities", style: :ghost, url: "#capabilities"'
    refute_includes home_view, 'text: "Authorization", style: :ghost, url: "#authorization"'
    assert_includes trash_bin_view, "FlatPack::PageTitle::Component"
    assert_includes trash_bin_view, "aria-label=\"Breadcrumb\""
    assert_includes trash_bin_view, 'icon: "arrow-left"'
    assert_includes trash_bin_view, "recording_studio_trashable_back_path"
    assert_includes trash_bin_view, "recording_studio_trashable_back_link_params"
    assert_includes trash_bin_view, "hidden_field_tag :back_path"
    assert_includes trash_bin_view, 'title: "Trash"'
    assert_includes trash_bin_view, 'subtitle: "Recently trashed items"'
    assert_includes trash_bin_view, "recording_studio_trashable_retention_settings_enabled?"
    assert_includes trash_bin_view, "recording_studio_trashable_page_authorized?(:settings"
    assert_includes trash_bin_view, 'text: "Trash settings"'
    assert_includes trash_bin_view,
                    "edit_recording_trash_settings_path(@scope_recording, recording_studio_trashable_back_link_params)"
    assert_includes trash_bin_view, "form_with url: recording_trash_bin_path(@scope_recording),"
    assert_includes trash_bin_view, "FlatPack::SearchInput::Component"
    assert_includes trash_bin_view, "@search_query"
    refute_includes trash_bin_view, 'label: "Search trashed items"'
    assert_includes trash_bin_view, 'placeholder: "Search trash"'
    assert_includes trash_bin_view, 'id: "trash-bin-search"'
    assert_includes trash_bin_view, 'data-controller="recording-studio-trashable--live-search"'
    assert_includes trash_bin_view, 'recording_studio_trashable__live_search_target: "form"'
    assert_includes trash_bin_view,
                    'action: "input->recording-studio-trashable--live-search#queueSubmit ' \
                    'search->recording-studio-trashable--live-search#queueSubmit"'
    assert_includes trash_bin_view, 'turbo_frame: "trash-bin-results"'
    assert_includes trash_bin_view, "recording_studio_trashable__live_search_delay_value: 250"
    assert_includes trash_bin_view, 'data-recording-studio-trashable--live-search-target="skeleton"'
    assert_includes trash_bin_view, "FlatPack::Skeleton::Component"
    assert_includes trash_bin_view, 'turbo_frame_tag "trash-bin-results"'
    assert_includes trash_bin_view, "turbo:before-fetch-request->recording-studio-trashable--live-search#showLoading"
    assert_includes trash_bin_view, "turbo:frame-load->recording-studio-trashable--live-search#hideLoading"
    assert_includes trash_bin_view, "hidden_field_tag :back_path, recording_studio_trashable_back_path"
    refute_includes trash_bin_view, 'FlatPack::Button::Component.new(text: "Search"'
    refute_includes trash_bin_view, 'text: "Clear"'
    assert_includes trash_bin_view, "No trashed items match your search."
    assert_includes trash_bin_view, ">Name<"
    assert_includes trash_bin_view, ">Type<"
    assert_includes trash_bin_view, ">Trashed<"
    assert_includes trash_bin_view, ">Action<"
    assert_includes trash_bin_view, "time_ago_in_words(recording.trashed_at)"
    assert_includes trash_bin_view, "FlatPack::Popover::Component"
    assert_includes trash_bin_view, "l(recording.trashed_at, format: :long)"
    assert_includes trash_bin_view, "recording_studio_trashable_action_authorized?(:restore"
    assert_includes trash_bin_view, "recording_studio_trashable_action_authorized?(:purge"
    assert_includes retention_view, "aria-label=\"Breadcrumb\""
    assert_includes retention_view, 'icon: "arrow-left"'
    assert_includes retention_view, "FlatPack::Button::Component"
    assert_includes retention_view, "recording_studio_trashable_back_path"
    assert_includes retention_view,
                    "recording_trash_settings_path(@scope_recording, recording_studio_trashable_back_link_params)"
    assert_includes retention_view, "max-w-5xl"
    assert_includes retention_view, 'class="text-sm text-(--surface-muted-content-color)"'
    assert_includes retention_view, 'title: "Retention period"'
    assert_includes retention_view, 'subtitle: "Number of days to keep trashed items."'
    assert_includes retention_view, "form.select :purge_after_days"
    assert_includes retention_view, 'text: "Save"'
    refute_includes retention_view, "FlatPack::Card::Component"
    refute_includes retention_view, 'text: "Back to trash bin"'
  end

  def test_engine_uses_a_blank_namespaced_layout
    application_controller = read_repo_file("../app/controllers/recording_studio_trashable/application_controller.rb")
    layout_view = read_repo_file("../app/views/layouts/recording_studio_trashable/application.html.erb")

    assert_includes application_controller, 'layout "recording_studio_trashable/application"'
    assert_includes application_controller, "recording_studio_trashable_retention_settings_enabled?"
    assert_includes application_controller, "def recording_studio_trashable_back_path"
    assert_includes application_controller, "def recording_studio_trashable_back_link_params"
    refute_includes layout_view, "FlatPack::SidebarLayout::Component"
    refute_includes layout_view, "layouts/flat_pack/top_nav"
    refute_includes layout_view, "layouts/flat_pack/sidebar"
  end

  def test_retention_copy_uses_select_based_retention_period_options
    retention_view = read_repo_file("../app/views/recording_studio_trashable/retention_settings/edit.html.erb")

    assert_includes retention_view, '"Keep until manually purged", ""'
    assert_includes retention_view, '"30 days", 30'
    refute_includes retention_view, "number_field :purge_after_days"
  end

  def test_controllers_stop_after_failed_mounted_page_authorization
    application_controller = read_repo_file("../app/controllers/recording_studio_trashable/application_controller.rb")
    recordings_controller = read_repo_file("../app/controllers/recording_studio_trashable/recordings_controller.rb")
    retention_controller = read_repo_file(
      "../app/controllers/recording_studio_trashable/retention_settings_controller.rb"
    )
    trash_bin_controller = read_repo_file("../app/controllers/recording_studio_trashable/trash_bins_controller.rb")

    assert_includes application_controller, "return if recording_studio_trashable_page_authorized?"
    assert_includes recordings_controller, "return if performed?"
    assert_includes retention_controller, "return if performed?"
    assert_includes retention_controller, "unless recording_studio_trashable_retention_settings_enabled?"
    assert_includes trash_bin_controller, "return if performed?"
    assert_includes trash_bin_controller, "@search_query = params[:q].to_s.strip"
    assert_includes trash_bin_controller, "trashed_recordings_for_query("
    assert_includes trash_bin_controller, "query: @search_query"
  end

  def test_dummy_tailwind_sources_include_flat_pack_gem_paths
    css = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes css, "vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}"
    assert_includes css, "vendor/bundle/**/flat_pack/app/components/**/*.{rb,erb}"
    assert_includes css, "flat_pack-*/app/components/**/*.{rb,erb}"
  end

  def test_engine_registers_live_search_assets
    engine_source = read_repo_file("../lib/recording_studio_trashable/engine.rb")
    importmap_source = read_repo_file("../config/importmap.rb")
    live_search_controller = read_repo_file(
      "../app/javascript/recording_studio_trashable/controllers/live_search_controller.js"
    )

    assert_includes engine_source, 'initializer "recording_studio_trashable.importmap"'
    assert_includes engine_source, 'app.config.importmap.paths << Engine.root.join("config/importmap.rb")'
    assert_includes engine_source, 'app.config.assets.paths << Engine.root.join("app/javascript")'
    assert_includes importmap_source, 'pin_all_from RecordingStudioTrashable::Engine.root.join("app/javascript/recording_studio_trashable/controllers")'
    assert_includes live_search_controller, "export default class extends Controller"
    assert_includes live_search_controller, "this.formTarget.requestSubmit()"
    assert_includes live_search_controller, "setTimeout(() => this.submit(), this.delayValue)"
    assert_includes live_search_controller, 'this.skeletonTarget.classList.remove("hidden")'
    assert_includes live_search_controller, 'this.skeletonTarget.classList.add("hidden")'
    assert_includes live_search_controller, 'this.frameTarget.style.visibility = "hidden"'
    assert_includes live_search_controller, 'this.frameTarget.style.visibility = ""'
    assert_includes live_search_controller, 'event.target.value.trim() === ""'
  end

  def test_dummy_home_mentions_workspace_and_project_trash_bins
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    source = File.read(view_path)

    assert_includes source, 'title: "Trash demo"'
    assert_includes source, 'subtitle: "Recoding Studio Trash functionality"'
    assert_includes source, 'text: "Trash can"'
    assert_includes source, 'text: "Trash settings"'
    assert_includes source, "back_path: main_app.root_path"
    assert_includes source, ">name<"
    assert_includes source, ">type<"
    assert_includes source, ">status<"
    assert_includes source, ">action<"
    assert_includes source, "recording_studio_trashable.trash_recording_path(recording)"
    assert_includes source, "recording_studio_trashable.restore_recording_path(recording)"
    assert_includes source, "recording_studio_trashable.purge_recording_path(recording)"
    assert_includes source, "recording_studio_trashable.edit_recording_trash_settings_path("
    assert_includes source, "@workspace_recording,"
    assert_includes source, "back_path: main_app.root_path"
    assert_includes source, "Trash not enabled"
    assert_includes source, "FlatPack::Popover::Component"
    assert_includes source, "This recordable type has not had trash enabled."
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

  def test_dummy_sidebar_icons_exist_in_the_sprite
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sprite_path = File.expand_path("dummy/app/views/layouts/_icon_sprite.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)
    sprite_source = File.read(sprite_path)

    sidebar_icons = sidebar_source.scan(/icon:\s*:(\w+(?:-\w+)*)/).flatten

    assert sidebar_icons.any?, "Expected the dummy sidebar to declare icons"

    sidebar_icons.each do |icon_name|
      assert_includes sprite_source, %(id="icon-#{icon_name}"), "Expected icon #{icon_name} to exist in the sprite"
    end
  end

  private

  def read_repo_file(path)
    File.read(File.expand_path(path, __dir__))
  end
end
