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
    assert_includes trash_bin_view, 'subtitle: "Recently trashed roots"'
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
    assert_includes trash_bin_view, "data-pagination-content"
    assert_includes trash_bin_view, "FlatPack::Pagination::Component"
    assert_includes trash_bin_view, "mode: :infinite"
    assert_includes trash_bin_view, "loading_variant: :table"
    assert_includes trash_bin_view, "hidden_field_tag :back_path, recording_studio_trashable_back_path"
    refute_includes trash_bin_view, 'FlatPack::Button::Component.new(text: "Search"'
    refute_includes trash_bin_view, 'text: "Clear"'
    assert_includes trash_bin_view, "No trash roots match your search."
    assert_includes trash_bin_view, ">Name<"
    assert_includes trash_bin_view, ">Type<"
    assert_includes trash_bin_view, ">Trashed<"
    assert_includes trash_bin_view, ">Action<"
    assert_includes trash_bin_view, "time_ago_in_words(recording.trashed_at)"
    assert_includes trash_bin_view, "FlatPack::Popover::Component"
    assert_includes trash_bin_view, "l(recording.trashed_at, format: :long)"
    assert_includes trash_bin_view, "recording_studio_trashable_action_authorized?(:restore"
    assert_includes trash_bin_view, "recording_studio_trashable_action_authorized?(:purge"
    assert_includes trash_bin_view, "form_with url: restore_recording_path("
    assert_includes trash_bin_view, "form_with url: purge_recording_path("
    assert_includes trash_bin_view, "hidden_field_tag :back_path, recording_studio_trashable_back_path"
    refute_includes trash_bin_view, 'redirect_target: "origin"'
    refute_includes trash_bin_view, "origin_path: request.fullpath"
    refute_includes trash_bin_view, "return_to_recording_id: @scope_recording.id"
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
    assert_includes application_controller, "include ::Pagy::Backend"
    assert_includes application_controller, "helper ::Pagy::Frontend"
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
    assert_includes trash_bin_controller, "PAGE_SIZE = 25"
    assert_includes trash_bin_controller, "@search_query = params[:q].to_s.strip"
    assert_includes trash_bin_controller, "trashed_recordings_for_query("
    assert_includes trash_bin_controller, "query: @search_query"
    assert_includes trash_bin_controller, ".reorder(trashed_at: :desc, id: :desc)"
    assert_includes trash_bin_controller, "@pagy, @trashed_recordings = pagy(trashed_recordings, limit: PAGE_SIZE)"
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
    controller_path = File.expand_path("dummy/app/controllers/home_controller.rb", __dir__)
    lookup_path = File.expand_path("dummy/app/models/demo_recording_lookup.rb", __dir__)
    trashable_initializer_path = File.expand_path("dummy/config/initializers/recording_studio_trashable.rb", __dir__)
    seeds_path = File.expand_path("dummy/db/seeds.rb", __dir__)
    routes_path = File.expand_path("dummy/config/routes.rb", __dir__)
    source = File.read(view_path)
    controller_source = File.read(controller_path)
    lookup_source = File.read(lookup_path)
    trashable_initializer_source = File.read(trashable_initializer_path)
    seeds_source = File.read(seeds_path)
    routes_source = File.read(routes_path)
    authorization_guard =
      "@can_purge_due = @workspace_recording.present? && RecordingStudioTrashable.authorized?("
    expired_default_retention = "expired_default_retention_recording.update!(trashed_at: 45.days.ago)"
    expired_scope_retention = "expired_scope_retention_recording.update!(trashed_at: 21.days.ago)"

    assert_includes source, "title: \"Trash demo\""
    assert_includes source, "subtitle: \"Recording Studio Trash functionality\""
    assert_includes source, "text: \"Trash can\""
    assert_includes source, "text: \"Trash settings\""
    assert_includes source, "text: \"Purge\""
    assert_includes source, "main_app.purge_due_recordings_path"
    assert_includes source, "back_path: main_app.root_path"
    assert_includes source, ">name<"
    assert_includes source, ">type<"
    assert_includes source, ">trash root<"
    assert_includes source, ">status<"
    assert_includes source, ">action<"
    assert_includes source, 'recording.trash_root? ? "yes" : "no"'
    assert_includes source, "recording_studio_trashable.trash_recording_path("
    assert_includes source, "recording_studio_trashable.restore_recording_path("
    assert_includes source, "recording_studio_trashable.purge_recording_path("
    assert_includes source, "data: { turbo: false }"
    assert_includes source, "hidden_field_tag :back_path, request.fullpath"
    refute_includes source, 'redirect_target: "origin"'
    refute_includes source, "origin_path: request.fullpath"
    refute_includes source, "return_to_recording_id: @workspace_recording.id"
    assert_includes source, "recording_studio_trashable.edit_recording_trash_settings_path("
    assert_includes source, "@workspace_recording,"
    assert_includes source, "back_path: main_app.root_path"
    assert_includes controller_source, "def purge_due"
    assert_includes controller_source, "RecordingStudioTrashable.purge_due_recordings_for_all_scopes("
    assert_includes controller_source, 'metadata: { source: "dummy_home_manual_purge" }'
    assert_includes controller_source, "action: :purge"
    assert_includes controller_source, authorization_guard
    assert_includes source, "Trash not enabled"
    assert_includes source, "FlatPack::Popover::Component"
    assert_includes source, "This recordable type has not had trash enabled."
    assert_includes controller_source, "DemoRecordingLookup.recent_projects(@workspace_recording, limit: 2)"
    assert_includes controller_source, "DemoRecordingLookup.recent_active_pages(@workspace_recording, limit: 2)"
    assert_includes controller_source, "DemoRecordingLookup.recent_trash_roots(@workspace_recording, limit: 2)"
    assert_includes lookup_source, "DEFAULT_HOME_TABLE_LIMIT = 2"
    assert_includes lookup_source, '.where(recordable_type: "Project")'
    assert_includes lookup_source, '.where(recordable_type: "Page")'
    assert_includes lookup_source, ".not_trashed"
    assert_includes lookup_source, "RecordingStudio::Recording.with_trashed"
    assert_includes lookup_source, ".recording_studio_trashable_trash_roots"
    assert_includes trashable_initializer_source, "Rails.application.config.to_prepare do"
    assert_includes trashable_initializer_source, "RecordingStudio::Recording.class_eval do"
    assert_includes trashable_initializer_source, "default_scope { where(trashed_at: nil) }"
    assert_includes trashable_initializer_source, "scope :not_trashed"
    assert_includes trashable_initializer_source, "scope :with_trashed"
    assert_includes routes_source, 'post "purge_due", to: "home#purge_due", as: :purge_due_recordings'
    assert_includes seeds_source, "slug: \"session-archive\""
    assert_includes seeds_source, "slug: \"release-checklist\""
    assert_includes seeds_source, "slug: \"expired-default-retention\""
    assert_includes seeds_source, "slug: \"expired-scope-retention\""
    assert_includes seeds_source, "slug: \"fresh-retention\""
    assert_includes seeds_source, expired_default_retention
    assert_includes seeds_source, expired_scope_retention
    assert_includes seeds_source, "fresh_retention_recording.update!(trashed_at: 5.days.ago)"
  end

  def test_dummy_layout_renders_flash_messages_with_flat_pack_alerts
    layout_path = File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__)
    sidebar_layout_path = File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__)
    source = File.read(layout_path)
    sidebar_source = File.read(sidebar_layout_path)

    assert_includes source, "flash.each do |type, message|"
    assert_includes source, "type.to_sym == :notice ? :success : :danger"
    assert_includes source, "FlatPack::Alert::Component"
    assert_includes sidebar_source, "flash.each do |type, message|"
    assert_includes sidebar_source, "type.to_sym == :notice ? :success : :danger"
    assert_includes sidebar_source, "FlatPack::Alert::Component"
  end

  def test_dummy_application_controller_provisions_demo_access_for_signed_in_users
    source = File.read(File.expand_path("dummy/app/controllers/application_controller.rb", __dir__))

    assert_includes source, "before_action :ensure_demo_access!"
    assert_includes source, "workspace_recording = DemoRecordingLookup.workspace_root"
    assert_includes source, "RecordingStudio::Access.find_or_initialize_by(actor: current_user)"
    assert_includes source, "access.role = :admin"
    assert_includes source, "access.save! if access.new_record? || access.changed?"
    assert_includes source, "recordable: access"
  end

  def test_devise_sign_in_view_keeps_form_in_normal_layout_flow
    source = File.read(File.expand_path("dummy/app/views/devise/sessions/new.html.erb", __dir__))

    assert_includes source, 'class="mx-auto flex w-full max-w-md flex-col justify-center px-4 py-8"'
    refute_includes source, 'class="fixed inset-0 p-4"'
  end

  def test_dummy_events_page_is_owned_by_dummy_app
    routes_source = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    controller_source = File.read(File.expand_path("dummy/app/controllers/events_controller.rb", __dir__))
    view_source = File.read(File.expand_path("dummy/app/views/events/show.html.erb", __dir__))
    sidebar_source = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))

    assert_includes routes_source, 'get "events", to: "events#show", as: :events'
    assert_includes controller_source, "class EventsController < ApplicationController"
    assert_includes(
      controller_source,
      "RecordingStudio::Event.includes(:recording, :recordable, " \
      ":previous_recordable, :actor, :impersonator).recent"
    )
    assert_includes controller_source, "helper_method :event_recording_label, :event_actor_label, :event_metadata"
    assert_includes controller_source, "\"\#{event.recordable_type} #\#{event.recordable_id.to_s.first(8)}\""
    assert_includes view_source, 'title: "Events"'
    assert_includes view_source, 'subtitle: "All Recording Studio events in the dummy app"'
    assert_includes view_source, "main_app.root_path"
    assert_includes view_source, "FlatPack::Popover::Component"
    assert_includes view_source, "event_recording_label(event)"
    assert_includes view_source, "event_actor_label(event)"
    assert_includes view_source, "event_metadata(event)"
    assert_includes view_source, "No events recorded yet."
    assert_includes sidebar_source, 'label: "Events"'
    assert_includes sidebar_source, "href: main_app.events_path"
    refute_includes sidebar_source, "recording_studio_trashable.recording_events_path"
  end

  def test_recordings_controller_redirects_back_by_default_and_supports_async_responses
    source = read_repo_file("../app/controllers/recording_studio_trashable/recordings_controller.rb")
    application_controller_source = read_repo_file(
      "../app/controllers/recording_studio_trashable/application_controller.rb"
    )

    assert_includes source, "respond_with_lifecycle_success(resolved_success_message)"
    assert_includes source, "respond_with_lifecycle_error(error.message)"
    assert_includes source, "return render json: { ok: true, notice: message } if async_response?"
    assert_includes(
      source,
      "return render json: { ok: false, alert: message }, status: :unprocessable_entity if async_response?"
    )
    assert_includes(
      source,
      'request.format.json? || boolean_param(params[:async]) || params[:redirect_target].to_s == "async"'
    )
    assert_includes source, "redirect_to sync_redirect_path"
    assert_includes source, "recording_studio_trashable_back_path(fallback: fallback_redirect_path)"
    assert_includes(
      source,
      "params[:return_to_recording_id].presence || params[:recording_id].presence || fallback_scope_id"
    )
    assert_includes source, "@recording.root_recording_id.presence || @recording.id"
    assert_includes application_controller_source, "url_from(params[:back_path].presence)"
    assert_includes application_controller_source, "url_from(request.referer)"
    assert_includes application_controller_source, "|| fallback"
    refute_includes source, 'return unless params[:redirect_target].to_s == "origin"'
    refute_includes source, "url_from(params[:origin_path].presence)"
  end

  def test_showcase_controller_lists_required_pages
    controller_path = File.expand_path("dummy/app/controllers/showcase_controller.rb", __dir__)
    showcase_view_path = File.expand_path("dummy/app/views/showcase/show.html.erb", __dir__)
    source = File.read(controller_path)
    showcase_view = File.read(showcase_view_path)
    trash_root_migration =
      "add_column :recording_studio_recordings, :trash_root, :boolean, default: false, null: false"

    assert_includes source, '"setup"'
    assert_includes(
      source,
      "subtitle: \"Install the addon, run the generators, migrate the schema, and wire up retention purging.\""
    )
    assert_includes source, 'title: "Install the gem"'
    assert_includes source, 'anchor_id: "install-the-gem"'
    assert_includes source, 'code_title: "Gemfile and optional manual mount"'
    assert_includes source, 'gem "recording_studio_trashable"'
    assert_includes source, 'mount RecordingStudioTrashable::Engine, at: "/recording_studio_trashable"'
    assert_includes source, 'title: "Run the generators"'
    assert_includes source, 'anchor_id: "run-the-generators"'
    assert_includes source, "bin/rails generate recording_studio_trashable:install"
    assert_includes source, "bin/rails generate recording_studio_trashable:migrations"
    assert_includes source, 'title: "Apply the database changes"'
    assert_includes source, 'anchor_id: "apply-the-database-changes"'
    assert_includes source, "add_column :recording_studio_recordings, :trashed_at, :datetime"
    assert_includes source, trash_root_migration
    assert_includes source, "create_table :recording_studio_trashable_retention_settings, id: :uuid do |t|"
    assert_includes source, 'title: "Schedule background purges"'
    assert_includes source, 'anchor_id: "schedule-background-purges"'
    assert_includes source, 'config.retention_purge_actor_resolver = -> { User.find_by!(email: "system@example.com") }'
    assert_includes source, "RecordingStudioTrashable::RetentionPurgeJob.perform_later"
    assert_includes source, '"configuration"'
    assert_includes source, '"adding-to-a-recordable"'
    assert_includes source, '"trash-cans"'
    assert_includes source, '"trash-roots"'
    assert_includes source, '"retention"'
    assert_includes source, '"responses"'
    assert_includes source, '"methods"'
    assert_includes source, 'title: "Trash cans"'
    assert_includes source, 'subtitle: "Trash-bin pages are scoped by the parent recording you pass in."'
    assert_includes source, 'body: "A trash can shows the trash roots beneath a specific recording.'
    assert_includes source, "recording_studio_trashable.recording_trash_bin_path(@project_recording)"
    assert_includes source, "recording_studio_trashable.recording_trash_bin_path(@root_recording)"
    assert_includes source, 'title: "Trash roots"'
    assert_includes source, 'subtitle: "Explicit restore points keep nested trash operations from undoing each other."'
    assert_includes source, 'title: "How trash roots work"'
    assert_includes source, 'anchor_id: "how-trash-roots-work"'
    assert_includes source, "that recording becomes the trash_root for its subtree"
    assert_includes source, "restore a parent subtree, the walk stops before a nested recording"
    assert_includes source, 'title: "Example recording tree"'
    assert_includes source, 'code_title: "Dot list with trash roots marked"'
    assert_includes source, ". Folder Archive (trash root)"
    assert_includes source, ". Page Release Checklist (trash root)"
    assert_includes source, 'title: "Why the boundary matters"'
    assert_includes source, "remains in the trash until restored directly"
    assert_includes source, 'title: "Retention"'
    assert_includes(
      source,
      'subtitle: "How the default retention window, optional user overrides, ' \
      'and purge sweep fit together."'
    )
    assert_includes source, 'title: "App-level retention"'
    assert_includes source, 'anchor_id: "app-level-retention"'
    assert_includes source, "config.default_purge_after_days = 30"
    assert_includes source, 'title: "Recordable level retention"'
    assert_includes source, 'anchor_id: "recordable-level-retention"'
    assert_includes source, 'subtitle: "Set different retention periods for different recordables"'
    assert_includes source, "include RecordingStudio::Capabilities::Trashable.to(purge_after_days: 14)"
    assert_includes source, 'title: "Allow users to set retention periods"'
    assert_includes source, "config.allow_user_retention_settings = true"
    assert_includes source, "settings: :admin"
    assert_includes source, 'title: "How the purge background task works"'
    assert_includes source, "RecordingStudioTrashable::RetentionPurgeJob"
    assert_includes source, "bundle exec rake recording_studio_trashable:purge_due"
    assert_includes source, "SCOPE_RECORDING_IDS=123,456"
    assert_includes source, 'title: "Responses"'
    assert_includes(
      source,
      'subtitle: "Lifecycle actions redirect back by default and only switch to JSON when async is requested."'
    )
    assert_includes source, 'title: "Reload existing page"'
    assert_includes source, 'subtitle: "Default behaviour"'
    assert_includes(
      source,
      'body: "After a recording is trashed, restored or purged the current page is refreshed ' \
      'and a flash message is returned."'
    )
    assert_includes source, 'title: "Async"'
    assert_includes source, 'subtitle: "Opt-in JSON responses"'
    assert_includes(
      source,
      'body: "Use async when the page should stay in place and handle the lifecycle result in ' \
      "JavaScript. Async requests skip the redirect and return a JSON payload with either a " \
      'notice or an alert."'
    )
    refute_includes source, "hidden_field_tag :back_path, request.fullpath"
    refute_includes source, "return_to_recording_id: @workspace_recording.id"
    assert_includes source, 'code_title: "Return to the current page after trashing"'
    assert_includes source, "include RecordingStudio::Capabilities::Trashable.to"
    assert_includes source, "recording_studio_trashable_purge!("
    assert_includes source, "recording_studio_trashable_filter(:active | :trashed | :all)"
    assert_includes source, "methods: ["
    assert_includes source, 'title: "Trash a recording"'
    assert_includes source, 'title: "Filter recordings by trash state"'
    assert_includes source, 'title: "Hide trashed recordings by default"'
    assert_includes source, 'anchor_id: "hide-trashed-recordings-by-default"'
    assert_includes source, "default_scope { where(trashed_at: nil) }"
    assert_includes source, "scope :not_trashed"
    assert_includes source, "scope :with_trashed"
    assert_includes source, 'anchor_id: "filter-recordings-by-trash-state"'
    assert_includes(
      source,
      "# Switch between active, trashed, or all recordings without changing the rest of the query."
    )
    assert_includes source, "project.recordings.recording_studio_trashable_filter(:trashed)"
    assert_includes source, 'anchor_id: "trash-a-recording"'
    assert_includes source, "# Soft delete the recording, cascade to descendants, and record who performed the action."
    assert_includes source, "# Remove the host app's default trash filter so both active and trashed rows are returned."
    assert_includes source, "recording_studio_trashable_active"
    assert_includes source, "project.recordings.not_trashed"
    assert_includes source, "project.recordings.with_trashed"
    assert_includes source, "recording_studio_trashable_trash_roots"
    assert_includes source, "recording_studio_trashable_trash_bin"
    assert_includes source, 'metadata: { source: "bulk-cleanup" }'
    assert_includes source, "RecordingStudioTrashable.configure do |config|"
    assert_includes source, "# Enables Accessible permission checks so trash actions respect the host app's role rules."
    assert_includes source, "config.allow_unconfigured_authorization = false"
    assert_includes source, "config.authorization_roles = {"
    assert_includes source, "settings: :admin"
    assert_includes source, "trash_bin: :edit"
    refute_includes source, "manage_retention: :admin"
    assert_includes source, "config.current_actor_resolver = ->(controller:) { controller.current_user }"
    assert_includes source, "config.current_impersonator_resolver = ->(controller:) { controller.true_user }"
    assert_includes showcase_view, "FlatPack::CodeBlock::Component"
    assert_includes showcase_view, "@page[:sections].present?"
    assert_includes showcase_view, "@page.fetch(:sections).each do |section|"
    assert_includes showcase_view, "title: section.fetch(:title)"
    assert_includes showcase_view, "subtitle: section[:subtitle]"
    assert_includes showcase_view, "anchor_id: section[:anchor_id]"
    assert_includes showcase_view, "simple_format(section.fetch(:body), class: \"text-sm leading-7\")"
    assert_includes showcase_view, "code: section.fetch(:code)"
    assert_includes showcase_view, "language: section[:code_language] || :ruby"
    assert_includes showcase_view, "@page[:methods].present?"
    assert_includes showcase_view, "FlatPack::SectionTitle::Component.new("
    assert_includes showcase_view, "title: method.fetch(:title)"
    assert_includes showcase_view, "subtitle: method.fetch(:name)"
    assert_includes showcase_view, "anchor_link: true"
    assert_includes showcase_view, "anchor_id: method[:anchor_id]"
    assert_includes showcase_view, "code: method.fetch(:code)"
    assert_includes showcase_view, "language: method[:code_language] || :ruby"
    assert_includes showcase_view, 'title: method[:code_title] || "Usage"'
    assert_includes showcase_view, "@page.fetch(:table_rows)"
    assert_includes showcase_view, "@page.fetch(:wrap_table_in_card, true)"
    assert_includes showcase_view, 'FlatPack::Table::Component.new(data: rows, class: "text-sm")'
    assert_includes showcase_view, '@page[:subtitle] || "Allow a recordable type to be trashed"'
    assert_includes showcase_view, "@page[:code_language] || :ruby"
    assert_includes showcase_view, '@page[:code_title] || "Code Example"'
  end

  def test_adding_to_a_recordable_owns_the_recordable_example_code
    controller_path = File.expand_path("dummy/app/controllers/showcase_controller.rb", __dir__)
    source = File.read(controller_path)

    setup_section = source[/"setup"\s*=>\s*\{.*?\n\s*\},\n/m]
    adding_section = source[/"adding-to-a-recordable"\s*=>\s*\{.*?\n\s*\},\n/m]

    refute_nil setup_section
    refute_nil adding_section
    refute_includes setup_section, 'code_title: "Adding trashable to a recordable type"'
    refute_includes setup_section, "include RecordingStudio::Capabilities::Trashable.to"
    assert_includes adding_section, 'code_title: "Adding trashable to a recordable type"'
    assert_includes adding_section, "include RecordingStudio::Capabilities::Trashable.to"
    refute_includes(
      adding_section,
      'body: "Only models that include RecordingStudio::Capabilities::Trashable.to ' \
      'receive the namespaced trash lifecycle on RecordingStudio::Recording."'
    )
  end

  def test_dummy_sidebar_icons_exist_in_the_sprite
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sprite_path = File.expand_path("dummy/app/views/layouts/_icon_sprite.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)
    sprite_source = File.read(sprite_path)

    assert_includes sidebar_source, 'label: "Overview"'
    assert_includes sidebar_source, 'href: main_app.showcase_path("overview")'
    assert_includes sidebar_source, 'label: "Events"'
    assert_includes sidebar_source, "href: main_app.events_path"
    assert_includes sidebar_source, 'label: "Retention"'
    assert_includes sidebar_source, 'href: main_app.showcase_path("retention")'
    assert_includes sidebar_source, 'label: "Responses"'
    assert_includes sidebar_source, 'href: main_app.showcase_path("responses")'
    assert_includes sidebar_source, 'label: "Trash cans"'
    assert_includes sidebar_source, 'href: main_app.showcase_path("trash-cans")'
    assert_includes sidebar_source, 'label: "Trash roots"'
    assert_includes sidebar_source, 'href: main_app.showcase_path("trash-roots")'

    sidebar_icons = sidebar_source.scan(/icon:\s*:(\w+(?:-\w+)*)/).flatten

    assert sidebar_icons.any?, "Expected the dummy sidebar to declare icons"

    sidebar_icons.each do |icon_name|
      assert_includes sprite_source, %(id="icon-#{icon_name}"), "Expected icon #{icon_name} to exist in the sprite"
    end
  end

  def test_overview_page_explains_trash_setup_and_boundaries
    controller_path = File.expand_path("dummy/app/controllers/showcase_controller.rb", __dir__)
    source = File.read(controller_path)

    overview_section = source[/"overview"\s*=>\s*\{.*?\n\s*\]\n\s*\},\n/m]

    refute_nil overview_section
    assert_includes overview_section, 'title: "Overview"'
    assert_includes overview_section, 'title: "Recording Studio specific trash"'
    assert_includes overview_section, 'title: "Timestamp based trash state"'
    assert_includes overview_section, 'title: "Trash and restore behavior"'
    assert_includes overview_section, 'title: "Subtree lifecycle"'
    assert_includes overview_section, 'title: "What is not trashed"'
    assert_includes overview_section, "recording_studio_recordings"
    assert_includes overview_section, "sets trashed_at to the current time"
    assert_includes overview_section, "clears trashed_at back to nil"
    assert_includes overview_section, "trash_root marks which trashed recordings appear in the trash bin"
    assert_includes overview_section, "operate on the targeted recording subtree"
    assert_includes overview_section, "does not soft-delete the underlying recordable data row"
    assert_includes overview_section, "does not trash Recording Studio event rows"
  end

  def test_readme_and_notes_document_optional_host_default_scope
    readme = read_repo_file("../README.md")
    notes = read_repo_file("../docs/recording_studio_trashable.md")

    assert_includes readme, "without forcing a global default scope on host apps"
    assert_includes readme, "default_scope { where(trashed_at: nil) }"
    assert_includes readme, "scope :not_trashed"
    assert_includes readme, "scope :with_trashed"
    assert_includes readme, "The addon does not introduce a new default scope."
    assert_includes notes, "## Host app query defaults"
    assert_includes notes, "default_scope { where(trashed_at: nil) }"
    assert_includes notes, "scope :not_trashed"
    assert_includes notes, "scope :with_trashed"
  end

  private

  def read_repo_file(path)
    File.read(File.expand_path(path, __dir__))
  end
end
