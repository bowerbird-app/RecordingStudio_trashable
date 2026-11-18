# frozen_string_literal: true

require_relative "../test_helper"

class TrashableApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    skip "Recording Studio API is not mounted" unless defined?(RecordingStudioApi)

    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    @admin = user("admin")
    Current.actor = @owner
    @workspace = owned_root(Workspace.create!(name: "API Workspace #{SecureRandom.hex(4)}"))
    @stranger = user("stranger")
    @other = owned_root(Workspace.create!(name: "Other workspace #{SecureRandom.hex(4)}"), actor: @stranger)
    @editor_access = grant!(@workspace, @editor, :edit)
    @viewer_access = grant!(@workspace, @viewer, :view)
    @admin_access = grant!(@workspace, @admin, :admin)
    @editor_token, = token_for(@editor_access)
    @viewer_token, = token_for(@viewer_access)
    @admin_token, = token_for(@admin_access)
    @page = record_page(@workspace, "Live Page")
  end

  teardown do
    Current.actor = @previous_actor
    RecordingStudioTrashable::Api::OpenapiOverrides.reset!
  end

  test "trash restore and trash bin rows match show fields" do
    register_access_role_field!

    shown = call(:get, "/pages/#{@page.id}", @editor_token)
    assert_response :success, response.body
    assert_equal "edit", shown.fetch("access_role")
    expected = resource_fields(shown)

    call(:post, "/pages/#{@page.id}/actions/trashable_trash", @viewer_token)
    assert_response :forbidden, response.body

    trashed = call(:post, "/pages/#{@page.id}/actions/trashable_trash", @editor_token)
    assert_response :success, response.body
    assert_equal expected, resource_fields(trashed)

    call(:get, "/pages/#{@page.id}/actions/trashable_list_trash_bin", @viewer_token)
    assert_response :forbidden, response.body

    listed = call(:get, "/pages/#{@page.id}/actions/trashable_list_trash_bin", @editor_token)
    assert_response :success, response.body
    row = listed.fetch("records").fetch(0)
    assert_equal expected, resource_fields(row)
    assert_equal "Live Page", row.fetch("label")
    assert_equal "Page", row.fetch("recordable_type")

    call(:post, "/pages/#{@page.id}/actions/trashable_restore", @viewer_token)
    assert_response :forbidden, response.body

    restored = call(:post, "/pages/#{@page.id}/actions/trashable_restore", @editor_token)
    assert_response :success, response.body
    shown_again = call(:get, "/pages/#{@page.id}", @editor_token)
    assert_response :success, response.body
    assert_equal resource_fields(shown_again), resource_fields(restored)
    assert_equal "edit", restored.fetch("access_role")
    assert_equal @page.reload.recordable.title, restored.fetch("title")
    assert_equal @page.recordable.slug, restored.fetch("slug")
  end

  test "trash restore purge and list_trash_bin succeed for the roles the screens use" do
    trashed = call(:post, "/pages/#{@page.id}/actions/trashable_trash", @editor_token)
    assert_response :success, response.body
    assert @page.reload.recording_studio_trashable_trashed?
    assert_equal @page.id, trashed.fetch("id")

    listed = call(:get, "/pages/#{@page.id}/actions/trashable_list_trash_bin", @editor_token)
    assert_response :success, response.body
    assert_equal [@page.id], listed.fetch("records").map { |row| row.fetch("id") }

    restored = call(:post, "/pages/#{@page.id}/actions/trashable_restore", @editor_token)
    assert_response :success, response.body
    assert @page.reload.recording_studio_trashable_kept?
    assert_equal @page.id, restored.fetch("id")

    call(:post, "/pages/#{@page.id}/actions/trashable_trash", @editor_token)
    assert_response :success, response.body

    purged = call(:post, "/pages/#{@page.id}/actions/trashable_purge", @admin_token)
    assert_response :success, response.body
    assert_equal true, purged.fetch("purged")
    assert_nil RecordingStudio::Recording.find_by(id: @page.id)
  end

  test "unauthenticated calls are 401" do
    post "#{BASE}/pages/#{@page.id}/actions/trashable_trash", as: :json
    assert_response :unauthorized

    post "#{BASE}/pages/#{@page.id}/actions/trashable_restore", as: :json
    assert_response :unauthorized

    post "#{BASE}/pages/#{@page.id}/actions/trashable_purge", as: :json
    assert_response :unauthorized

    get "#{BASE}/pages/#{@page.id}/actions/trashable_list_trash_bin", as: :json
    assert_response :unauthorized
  end

  test "view is forbidden from trash restore purge and the trash bin" do
    call(:post, "/pages/#{@page.id}/actions/trashable_trash", @viewer_token)
    assert_response :forbidden, response.body

    @page.recording_studio_trashable_trash!(actor: @owner)

    call(:post, "/pages/#{@page.id}/actions/trashable_restore", @viewer_token)
    assert_response :forbidden, response.body

    call(:post, "/pages/#{@page.id}/actions/trashable_purge", @viewer_token)
    assert_response :forbidden, response.body

    call(:get, "/pages/#{@page.id}/actions/trashable_list_trash_bin", @viewer_token)
    assert_response :forbidden, response.body
  end

  test "edit is forbidden from purge" do
    @page.recording_studio_trashable_trash!(actor: @owner)

    call(:post, "/pages/#{@page.id}/actions/trashable_purge", @editor_token)
    assert_response :forbidden, response.body
  end

  test "a page in another workspace is not found" do
    stranger_page = record_page(@other, "Elsewhere", actor: @stranger)

    call(:post, "/pages/#{stranger_page.id}/actions/trashable_trash", @editor_token)
    assert_response :not_found, response.body

    stranger_page.recording_studio_trashable_trash!(actor: @stranger)

    call(:post, "/pages/#{stranger_page.id}/actions/trashable_restore", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/pages/#{stranger_page.id}/actions/trashable_purge", @admin_token)
    assert_response :not_found, response.body

    call(:get, "/pages/#{stranger_page.id}/actions/trashable_list_trash_bin", @editor_token)
    assert_response :not_found, response.body
  end

  test "wrong state and bad input are 422" do
    call(:post, "/pages/#{@page.id}/actions/trashable_restore", @editor_token)
    assert_response :unprocessable_entity, response.body

    call(:post, "/pages/#{@page.id}/actions/trashable_purge", @admin_token)
    assert_response :unprocessable_entity, response.body

    call(:post, "/pages/#{@page.id}/actions/trashable_trash", @editor_token)
    assert_response :success, response.body

    call(:post, "/pages/#{@page.id}/actions/trashable_trash", @editor_token)
    assert_response :not_found, response.body

    call(:get, "/pages/#{@page.id}/actions/trashable_list_trash_bin", @editor_token, per_page: "nope")
    assert_response :unprocessable_entity, response.body
  end

  test "list_trash_bin searches with q" do
    parent = record_page(@workspace, "Keep Me")
    match = record_page(parent, "Mix Notes")
    other = record_page(parent, "Release Checklist")
    match.recording_studio_trashable_trash!(actor: @owner)
    other.recording_studio_trashable_trash!(actor: @owner)

    listed = call(:get, "/pages/#{parent.id}/actions/trashable_list_trash_bin", @editor_token, q: "  Mix  ")
    assert_response :success, response.body
    assert_equal ["Mix Notes"], listed.fetch("records").map { |row| row["title"] }
  end

  test "list_trash_bin pages with a stable order and no overlap" do
    parent = record_page(@workspace, "Bin Parent")
    trashed = 26.times.map do |index|
      page = record_page(parent, format("Trashed %02d", index))
      page.recording_studio_trashable_trash!(actor: @owner)
      page.update_column(:trashed_at, Time.utc(2026, 1, 1, 12, 0, index))
      page.reload
    end
    expected = trashed.sort_by { |page| [-page.trashed_at.to_i, -page.id] }.map(&:id)

    default_page = call(:get, "/pages/#{parent.id}/actions/trashable_list_trash_bin", @editor_token)
    assert_response :success, response.body
    first = call(:get, "/pages/#{parent.id}/actions/trashable_list_trash_bin", @editor_token, page: 1, per_page: 25)
    assert_response :success, response.body
    second = call(:get, "/pages/#{parent.id}/actions/trashable_list_trash_bin", @editor_token, page: 2, per_page: 25)
    assert_response :success, response.body

    first_ids = first.fetch("records").map { |row| row.fetch("id") }
    second_ids = second.fetch("records").map { |row| row.fetch("id") }

    assert_equal 25, first_ids.size
    assert_equal 1, second_ids.size
    assert_empty first_ids & second_ids
    assert_equal expected.first(25), first_ids
    assert_equal expected.last(1), second_ids
    assert_equal first_ids, default_page.fetch("records").map { |row| row.fetch("id") }
  end

  test "list_trash_bin clamps per_page above 100" do
    parent = record_page(@workspace, "Clamp Parent")
    101.times do |index|
      page = record_page(parent, format("Clamp %03d", index))
      page.recording_studio_trashable_trash!(actor: @owner)
    end

    listed = call(:get, "/pages/#{parent.id}/actions/trashable_list_trash_bin", @editor_token, per_page: 1000)
    assert_response :success, response.body
    assert_equal 100, listed.fetch("records").size
  end

  test "list_trash_bin honours a host authorization_resolver" do
    previous = RecordingStudioTrashable.configuration.authorization_resolver
    RecordingStudioTrashable.configuration.authorization_resolver = lambda { |**payload|
      payload.fetch(:action) != :trash_bin
    }

    call(:get, "/pages/#{@page.id}/actions/trashable_list_trash_bin", @editor_token)
    assert_response :forbidden, response.body
  ensure
    RecordingStudioTrashable.configuration.authorization_resolver = previous
  end

  test "registering the api twice does not raise" do
    2.times { RecordingStudioTrashable::Api.register! }

    trash = RecordingStudioApi.capability_action(:trashable_trash)
    assert_equal RecordingStudioTrashable::Api::Actions::Trash, trash.handler
  end

  test "a mismatched existing registration raises" do
    original = RecordingStudioApi.instance_variable_get(:@configuration)
    RecordingStudioApi.instance_variable_set(:@configuration, RecordingStudioApi::Configuration.new)
    RecordingStudioApi.configure { |config| config.api :conflict }
    RecordingStudioApi.register_capability_action(
      :trashable_trash,
      api: :conflict,
      capability: :trashable,
      handler: ->(_context) {},
      http_verb: :post,
      required_role: :edit
    )

    error = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioTrashable::Api.register!
    end
    assert_match(/trashable_trash/, error.message)
    assert_match(/different handler/, error.message)
  ensure
    RecordingStudioApi.instance_variable_set(:@configuration, original) if original
    RecordingStudioTrashable::Api.register!
  end

  test "capability actions match screen roles" do
    trash = RecordingStudioApi.capability_action(:trashable_trash)
    restore = RecordingStudioApi.capability_action(:trashable_restore)
    purge = RecordingStudioApi.capability_action(:trashable_purge)
    list = RecordingStudioApi.capability_action(:trashable_list_trash_bin)

    assert_equal :edit, trash.required_role
    assert_equal :edit, restore.required_role
    assert_equal :admin, purge.required_role
    assert_equal :edit, list.required_role
    assert_equal false, trash.include_trashed
    assert_nil trash.trashed_semantics
    assert_equal true, restore.include_trashed
    assert_equal :restore, restore.trashed_semantics
    assert_equal true, purge.include_trashed
    assert_equal :destroy, purge.trashed_semantics
    assert_equal true, list.include_trashed
    assert_nil list.trashed_semantics

    page_handler = RecordingStudioApi.resource_handler_registration("Page", :trashable_restore)
    assert_equal true, page_handler.include_trashed
    assert_equal :restore, page_handler.trashed_semantics
    assert_equal :trashable, trash.capability
    assert_equal :get, list.http_verb
    assert_equal "Trash", trash.openapi.fetch(:title)
    assert_equal "Restore", restore.openapi.fetch(:title)
    assert_equal "Purge", purge.openapi.fetch(:title)
    assert_equal "List trash bin", list.openapi.fetch(:title)
    assert_equal "Trash page", trash.openapi_for(type: "Page", action: :trashable_trash).fetch(:title)
    assert_equal "List page trash bin", list.openapi_for(type: "Page", action: :trashable_list_trash_bin).fetch(:title)
    [trash, restore, purge, list].each do |action|
      assert_equal "Trash", action.openapi.fetch(:tag_suffix)
    end
    assert_nil trash.serializer
  end

  test "trash handlers register for trashable types only" do
    actions = %i[trashable_trash trashable_restore trashable_purge trashable_list_trash_bin]

    RecordingStudioApi.configuration.each_api do |api|
      RecordingStudio.configuration.recordable_types.each do |type|
        actions.each do |action|
          handler = RecordingStudioApi.resource_handler(type, action, api: api.name)
          if RecordingStudio.capability_enabled?(:trashable, for: type)
            assert handler, "#{api.name} #{type} #{action}"
          else
            assert_nil handler, "#{api.name} #{type} #{action}"
          end
        end
      end
    end
  end

  test "per-type trash titles follow the recordable label and an override wins" do
    trash = RecordingStudioApi.capability_action(:trashable_trash)
    restore = RecordingStudioApi.capability_action(:trashable_restore)
    purge = RecordingStudioApi.capability_action(:trashable_purge)
    list = RecordingStudioApi.capability_action(:trashable_list_trash_bin)

    assert_equal "Trash page", trash.openapi_for(type: "Page", action: :trashable_trash).fetch(:title)
    assert_equal "Restore folder", restore.openapi_for(type: "Folder", action: :trashable_restore).fetch(:title)
    assert_equal "Purge project", purge.openapi_for(type: "Project", action: :trashable_purge).fetch(:title)
    assert_equal "List workspace trash bin", list.openapi_for(type: "Workspace", action: :trashable_list_trash_bin).fetch(:title)
    assert_equal "Trash", trash.openapi_for(type: "NotARecordable", action: :trashable_trash).fetch(:title)
    assert_equal "Trash", trash.openapi.fetch(:title)

    RecordingStudioTrashable::Api.override_openapi(
      type: "Page",
      action: :trashable_trash,
      title: "Bin this page",
      description: "Custom page trash copy."
    )

    page = trash.openapi_for(type: "Page", action: :trashable_trash)
    folder = trash.openapi_for(type: "Folder", action: :trashable_trash)

    assert_equal "Bin this page", page.fetch(:title)
    assert_equal "Custom page trash copy.", page.fetch(:description)
    assert_equal "Trash", page.fetch(:tag_suffix)
    assert_equal "Trash folder", folder.fetch(:title)
    assert_equal "Trash", trash.openapi.fetch(:title)
  ensure
    RecordingStudioTrashable::Api::OpenapiOverrides.reset!
  end

  test "list trash bin records include label and recordable type" do
    parent = trashable_project("Label Parent")
    titled = record_page(parent, "Launch Notes")
    named = record_folder(parent, "Reference Assets")
    blank = record_page(parent, "Placeholder")
    Page.where(id: blank.recordable_id).update_all(title: "")
    titled.recording_studio_trashable_trash!(actor: @owner)
    blank.recording_studio_trashable_trash!(actor: @owner)
    mark_trash_root(named)

    listed = call(:get, "/projects/#{parent.id}/actions/trashable_list_trash_bin", @editor_token)
    assert_response :success, response.body
    rows = listed.fetch("records").index_by { |row| row.fetch("id") }

    assert_equal "Launch Notes", rows.fetch(titled.id).fetch("label")
    assert_equal "Page", rows.fetch(titled.id).fetch("recordable_type")
    assert_equal "Reference Assets", rows.fetch(named.id).fetch("label")
    assert_equal "Folder", rows.fetch(named.id).fetch("recordable_type")
    assert_equal "Page ##{blank.id.to_s.first(8)}", rows.fetch(blank.id).fetch("label")
    assert_equal "Page", rows.fetch(blank.id).fetch("recordable_type")
  end

  test "recording_id restores and purges a trash root in the subtree" do
    parent = trashable_project("Action Parent")
    child = record_page(parent, "Nested Page")
    folder = record_folder(parent, "Nested Folder")
    child.recording_studio_trashable_trash!(actor: @owner)
    assert_raises(RecordingStudio::CapabilityDisabled) do
      folder.recording_studio_trashable_trash!(actor: @owner)
    end
    mark_trash_root(folder)

    restored = call(
      :post,
      "/projects/#{parent.id}/actions/trashable_restore",
      @editor_token,
      recording_id: child.id
    )
    assert_response :success, response.body
    assert child.reload.recording_studio_trashable_kept?
    assert_equal child.id, restored.fetch("id")

    mark_trash_root(folder)
    restored_folder = call(
      :post,
      "/projects/#{parent.id}/actions/trashable_restore",
      @editor_token,
      recording_id: folder.id
    )
    assert_response :success, restored_folder.inspect
    assert folder.reload.recording_studio_trashable_kept?

    child.recording_studio_trashable_trash!(actor: @owner)
    purged = call(
      :post,
      "/projects/#{parent.id}/actions/trashable_purge",
      @admin_token,
      recording_id: child.id
    )
    assert_response :success, response.body
    assert_equal true, purged.fetch("purged")
    assert_nil RecordingStudio::Recording.find_by(id: child.id)

    mark_trash_root(folder)
    purged_folder = call(
      :post,
      "/projects/#{parent.id}/actions/trashable_purge",
      @admin_token,
      recording_id: folder.id
    )
    assert_response :success, purged_folder.inspect
    assert_nil RecordingStudio::Recording.find_by(id: folder.id)
  end

  test "recording_id restore and purge are denied without permission on the nested item" do
    parent = record_page(@workspace, "Denied Parent")
    child = record_page(parent, "Denied Child")
    child.recording_studio_trashable_trash!(actor: @owner)
    previous = RecordingStudioTrashable.configuration.authorization_resolver
    RecordingStudioTrashable.configuration.authorization_resolver = lambda { |**payload|
      payload.fetch(:recording).id == child.id ? false : nil
    }

    call(:post, "/pages/#{parent.id}/actions/trashable_restore", @editor_token, recording_id: child.id)
    assert_response :forbidden, response.body
    assert child.reload.recording_studio_trashable_trashed?

    call(:post, "/pages/#{parent.id}/actions/trashable_purge", @admin_token, recording_id: child.id)
    assert_response :forbidden, response.body
    assert child.reload.recording_studio_trashable_trashed?
    assert RecordingStudio::Recording.find_by(id: child.id)
  ensure
    RecordingStudioTrashable.configuration.authorization_resolver = previous
  end

  test "recording_id outside the subtree is not found" do
    parent = record_page(@workspace, "Scope Parent")
    outside = record_page(@workspace, "Outside Page")
    outside.recording_studio_trashable_trash!(actor: @owner)

    call(:post, "/pages/#{parent.id}/actions/trashable_restore", @editor_token, recording_id: outside.id)
    assert_response :not_found, response.body
    assert_includes response.body, "Resource was not found in this API scope"
    assert outside.reload.recording_studio_trashable_trashed?
  end

  test "recording_id in the subtree is not found unless it is a trash root" do
    parent = record_page(@workspace, "Subtree Parent")
    kept = record_page(parent, "Kept Child")
    branch = record_page(parent, "Trashed Branch")
    leaf = record_page(branch, "Cascade Leaf")
    branch.recording_studio_trashable_trash!(actor: @owner)

    call(:post, "/pages/#{parent.id}/actions/trashable_restore", @editor_token, recording_id: kept.id)
    assert_response :not_found, response.body
    assert_includes response.body, "Resource was not found in this API scope"
    assert kept.reload.recording_studio_trashable_kept?

    call(:post, "/pages/#{parent.id}/actions/trashable_purge", @admin_token, recording_id: leaf.id)
    assert_response :not_found, response.body
    assert_includes response.body, "Resource was not found in this API scope"
    assert leaf.reload.recording_studio_trashable_trashed?
    refute leaf.trash_root?
  end

  test "restore by recording_id leaves a nested trash root trashed" do
    parent = record_page(@workspace, "Cascade Parent")
    branch = record_page(parent, "Cascade Branch")
    nested = record_page(branch, "Nested Root")
    nested.recording_studio_trashable_trash!(actor: @owner)
    branch.recording_studio_trashable_trash!(actor: @owner)

    call(:post, "/pages/#{parent.id}/actions/trashable_restore", @editor_token, recording_id: branch.id)
    assert_response :success, response.body
    assert branch.reload.recording_studio_trashable_kept?
    assert nested.reload.recording_studio_trashable_trashed?
    assert nested.trash_root?
  end

  test "purge by recording_id deletes only trashed rows leaf first" do
    RecordingStudio::Event.class_eval do
      def remember_purged_recording
        return unless action == "purged"

        Thread.current[:purged_recording_ids] << recording_id
      end
    end
    RecordingStudio::Event.after_create :remember_purged_recording
    Thread.current[:purged_recording_ids] = []

    parent = record_page(@workspace, "Purge Parent")
    branch = record_page(parent, "Purge Branch")
    branch.recording_studio_trashable_trash!(actor: @owner)
    leaf = record_page(branch, "Purge Leaf")

    call(:post, "/pages/#{parent.id}/actions/trashable_purge", @admin_token, recording_id: branch.id)
    assert_response :unprocessable_entity, response.body
    assert_includes response.body, "already be trashed"
    assert branch.reload.recording_studio_trashable_trashed?
    assert leaf.reload.recording_studio_trashable_kept?

    leaf.recording_studio_trashable_trash!(actor: @owner)
    branch_id = branch.id
    leaf_id = leaf.id
    purged = call(:post, "/pages/#{parent.id}/actions/trashable_purge", @admin_token, recording_id: branch.id)
    assert_response :success, response.body
    assert_equal true, purged.fetch("purged")
    assert_nil RecordingStudio::Recording.find_by(id: branch_id)
    assert_nil RecordingStudio::Recording.find_by(id: leaf_id)

    assert_equal [leaf_id, branch_id], Thread.current[:purged_recording_ids]
  ensure
    RecordingStudio::Event.skip_callback(:create, :after, :remember_purged_recording)
    Thread.current[:purged_recording_ids] = nil
  end

  test "restore and purge without recording_id still target the path recording" do
    page = record_page(@workspace, "Plain Page")
    other = record_page(@workspace, "Plain Other")
    page.recording_studio_trashable_trash!(actor: @owner)
    other.recording_studio_trashable_trash!(actor: @owner)

    restored = call(:post, "/pages/#{page.id}/actions/trashable_restore", @editor_token, recording_id: "")
    assert_response :success, response.body
    assert page.reload.recording_studio_trashable_kept?
    assert other.reload.recording_studio_trashable_trashed?
    assert_equal page.id, restored.fetch("id")

    page.recording_studio_trashable_trash!(actor: @owner)
    purged = call(:post, "/pages/#{page.id}/actions/trashable_purge", @admin_token)
    assert_response :success, response.body
    assert_equal true, purged.fetch("purged")
    assert_nil RecordingStudio::Recording.find_by(id: page.id)
    assert other.reload.recording_studio_trashable_trashed?
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.create_root_recording!(recordable, actor: actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: actor)
    raise result.error if result.failure?

    root
  end

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(recording: recording, actor: actor, role: role, manager_actor: @owner)
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
  end

  def record_page(parent, title, actor: @owner)
    parent.record(Page, actor: actor, parent_recording: parent) do |page|
      page.title = title
      page.slug = "#{title.parameterize}-#{SecureRandom.hex(4)}"
      page.body = "API demo page"
    end
  end

  def record_folder(parent, name, actor: @owner)
    parent.record(Folder, actor: actor, parent_recording: parent) do |folder|
      folder.name = name
      folder.slug = "#{name.parameterize}-#{SecureRandom.hex(4)}"
    end
  end

  def trashable_project(name)
    enable_project_trashable!
    @workspace.record(Project, actor: @owner, parent_recording: @workspace) do |project|
      project.name = name
      project.slug = "#{name.parameterize}-#{SecureRandom.hex(4)}"
    end
  end

  def enable_project_trashable!
    return if RecordingStudio.capability_enabled?(:trashable, for: "Project")

    Project.include RecordingStudio::Capabilities::Trashable.to
    if RecordingStudioApi.recordable_registration_for("Project").nil?
      RecordingStudioApi.register_recordable_type_api("Project", operations: %i[show])
    end
    RecordingStudioTrashable::Api.register!
  end

  def mark_trash_root(recording)
    recording.update_columns(trashed_at: Time.current, trash_root: true, purge_at: nil, updated_at: Time.current)
    recording.reload
  end

  RESOURCE_FIELDS = %w[id type parent_id root_id title slug access_role].freeze

  def resource_fields(payload)
    RESOURCE_FIELDS.index_with { |key| payload.fetch(key) }
  end

  def register_access_role_field!
    registration = RecordingStudioApi.recordable_registration_for("Page")
    return if registration&.fields&.key?("access_role")

    RecordingStudioApi.register_recordable_type_api(
      "Page",
      fields: {
        access_role: {
          include: true,
          resolver: ->(field_context) { field_context.access_grant.role.to_s }
        }
      }
    )
  end

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params: params, headers: {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json"
    }, as: :json)
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end
end
