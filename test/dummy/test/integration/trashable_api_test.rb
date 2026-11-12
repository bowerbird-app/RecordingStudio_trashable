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

  teardown { Current.actor = @previous_actor }

  test "trash restore purge and list_trash_bin succeed for the roles the screens use" do
    trashed = call(:post, "/pages/#{@page.id}/actions/trash", @editor_token)
    assert_response :success, response.body
    assert @page.reload.recording_studio_trashable_trashed?
    assert_equal @page.id, trashed.fetch("id")

    listed = call(:get, "/pages/#{@page.id}/actions/list_trash_bin", @editor_token)
    assert_response :success, response.body
    assert_equal [@page.id], listed.fetch("records").map { |row| row.fetch("id") }

    restored = call(:post, "/pages/#{@page.id}/actions/restore", @editor_token)
    assert_response :success, response.body
    assert @page.reload.recording_studio_trashable_kept?
    assert_equal @page.id, restored.fetch("id")

    call(:post, "/pages/#{@page.id}/actions/trash", @editor_token)
    assert_response :success, response.body

    purged = call(:post, "/pages/#{@page.id}/actions/purge", @admin_token)
    assert_response :success, response.body
    assert_equal true, purged.fetch("purged")
    assert_nil RecordingStudio::Recording.recording_studio_trashable_including_trashed.find_by(id: @page.id)
  end

  test "unauthenticated calls are 401" do
    post "#{BASE}/pages/#{@page.id}/actions/trash", as: :json
    assert_response :unauthorized

    post "#{BASE}/pages/#{@page.id}/actions/restore", as: :json
    assert_response :unauthorized

    post "#{BASE}/pages/#{@page.id}/actions/purge", as: :json
    assert_response :unauthorized

    get "#{BASE}/pages/#{@page.id}/actions/list_trash_bin", as: :json
    assert_response :unauthorized
  end

  test "view is forbidden from trash restore purge and the trash bin" do
    call(:post, "/pages/#{@page.id}/actions/trash", @viewer_token)
    assert_response :forbidden, response.body

    @page.recording_studio_trashable_trash!(actor: @owner)

    call(:post, "/pages/#{@page.id}/actions/restore", @viewer_token)
    assert_response :forbidden, response.body

    call(:post, "/pages/#{@page.id}/actions/purge", @viewer_token)
    assert_response :forbidden, response.body

    call(:get, "/pages/#{@page.id}/actions/list_trash_bin", @viewer_token)
    assert_response :forbidden, response.body
  end

  test "edit is forbidden from purge" do
    @page.recording_studio_trashable_trash!(actor: @owner)

    call(:post, "/pages/#{@page.id}/actions/purge", @editor_token)
    assert_response :forbidden, response.body
  end

  test "a page in another workspace is not found" do
    stranger_page = record_page(@other, "Elsewhere", actor: @stranger)

    call(:post, "/pages/#{stranger_page.id}/actions/trash", @editor_token)
    assert_response :not_found, response.body

    stranger_page.recording_studio_trashable_trash!(actor: @stranger)

    call(:post, "/pages/#{stranger_page.id}/actions/restore", @editor_token)
    assert_response :not_found, response.body

    call(:post, "/pages/#{stranger_page.id}/actions/purge", @admin_token)
    assert_response :not_found, response.body

    call(:get, "/pages/#{stranger_page.id}/actions/list_trash_bin", @editor_token)
    assert_response :not_found, response.body
  end

  test "wrong state and bad input are 422" do
    call(:post, "/pages/#{@page.id}/actions/restore", @editor_token)
    assert_response :unprocessable_entity, response.body

    call(:post, "/pages/#{@page.id}/actions/purge", @admin_token)
    assert_response :unprocessable_entity, response.body

    call(:post, "/pages/#{@page.id}/actions/trash", @editor_token)
    assert_response :success, response.body

    call(:post, "/pages/#{@page.id}/actions/trash", @editor_token)
    assert_response :unprocessable_entity, response.body

    call(:get, "/pages/#{@page.id}/actions/list_trash_bin", @editor_token, limit: "nope")
    assert_response :unprocessable_entity, response.body
  end

  test "list_trash_bin searches with q" do
    parent = record_page(@workspace, "Keep Me")
    match = record_page(parent, "Mix Notes")
    other = record_page(parent, "Release Checklist")
    match.recording_studio_trashable_trash!(actor: @owner)
    other.recording_studio_trashable_trash!(actor: @owner)

    listed = call(:get, "/pages/#{parent.id}/actions/list_trash_bin", @editor_token, q: "Mix")
    assert_response :success, response.body
    assert_equal ["Mix Notes"], listed.fetch("records").map { |row| row["title"] }
  end

  test "capability actions match screen roles" do
    trash = RecordingStudioApi.capability_action(:trash)
    restore = RecordingStudioApi.capability_action(:restore)
    purge = RecordingStudioApi.capability_action(:purge)
    list = RecordingStudioApi.capability_action(:list_trash_bin)

    assert_equal :edit, trash.required_role
    assert_equal :edit, restore.required_role
    assert_equal :admin, purge.required_role
    assert_equal :edit, list.required_role
    assert_equal :trashable, trash.capability
    assert_equal :get, list.http_verb
    assert_equal "Trash - Restore", restore.openapi.fetch(:title)
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
    root = RecordingStudio.root_recording_for(recordable)
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
