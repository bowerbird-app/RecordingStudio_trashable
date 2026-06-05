# frozen_string_literal: true

require "test_helper"
require "active_record"
require "action_controller"
require "action_dispatch/middleware/flash"
require "action_dispatch/testing/test_request"
require "action_dispatch/testing/test_response"
require "json"
require "uri"

unless defined?(ApplicationController)
  class ApplicationController < ActionController::Base
  end
end

require_relative "../app/controllers/recording_studio_trashable/application_controller"
require_relative "../app/controllers/recording_studio_trashable/recordings_controller"
require_relative "../app/controllers/recording_studio_trashable/retention_settings_controller"
require_relative "../app/controllers/recording_studio_trashable/trash_bins_controller"

class ControllerBehaviorTest < Minitest::Test
  FakeRecordable = Struct.new(:title, :name, keyword_init: true)
  FakeScopeRecording = Struct.new(:id, keyword_init: true)

  class FakeRecording
    attr_reader :recordable, :lifecycle_calls
    attr_accessor :id, :root_recording_id, :recordable_type

    def initialize(id: "rec-1", title: nil, name: nil, root_recording_id: nil, recordable_type: "Page")
      @id = id
      @root_recording_id = root_recording_id
      @recordable_type = recordable_type
      @recordable = FakeRecordable.new(title: title, name: name)
      @lifecycle_calls = {}
    end

    def recording_studio_trashable_trash!(**kwargs)
      @lifecycle_calls[:trash] = kwargs
    end

    def recording_studio_trashable_restore!(**kwargs)
      @lifecycle_calls[:restore] = kwargs
    end

    def recording_studio_trashable_purge!(**kwargs)
      @lifecycle_calls[:purge] = kwargs
    end
  end

  class FakeRetentionSetting
    attr_reader :assigned_attributes

    def initialize(save_result: true)
      @save_result = save_result
    end

    def assign_attributes(attributes)
      @assigned_attributes = attributes
    end

    def save
      @save_result
    end
  end

  class FakeRelation
    attr_reader :reorder_arguments

    def reorder(*arguments)
      @reorder_arguments = arguments
      self
    end
  end

  def test_trash_redirects_with_notice_and_server_owned_metadata
    controller = build_controller(RecordingStudioTrashable::RecordingsController, params: { id: "rec-1" })
    recording = FakeRecording.new(title: "Mix Notes")

    controller.define_singleton_method(:find_recording!) { |_id| recording }
    controller.define_singleton_method(:authorize_recording_action!) { |_action, recording:| recording }
    controller.define_singleton_method(:current_trashable_actor) { :editor }
    controller.define_singleton_method(:current_trashable_impersonator) { :admin }
    controller.define_singleton_method(:sync_redirect_path) { "/back" }

    controller.trash

    assert_equal "/back", URI.parse(controller.response.location).path
    assert_equal "Mix Notes moved to trash", controller.flash[:notice]
    assert_equal(
      {
        actor: :editor,
        impersonator: :admin,
        metadata: {
          source: "recording_studio_trashable_ui",
          request_id: "req-123"
        }
      },
      recording.lifecycle_calls[:trash]
    )
  end

  def test_trash_stops_after_authorization_redirect
    controller = build_controller(RecordingStudioTrashable::RecordingsController, params: { id: "rec-1" })
    recording = FakeRecording.new(title: "Mix Notes")

    controller.define_singleton_method(:find_recording!) { |_id| recording }
    controller.define_singleton_method(:authorize_recording_action!) do |_action, **_kwargs|
      redirect_to "/blocked"
    end

    controller.trash

    assert_equal "/blocked", URI.parse(controller.response.location).path
    assert_nil recording.lifecycle_calls[:trash]
  end

  def test_restore_redirects_with_restored_notice
    controller = build_controller(RecordingStudioTrashable::RecordingsController, params: { id: "rec-1" })
    recording = FakeRecording.new(title: "Mix Notes")

    controller.define_singleton_method(:find_recording!) { |_id| recording }
    controller.define_singleton_method(:authorize_recording_action!) { |_action, recording:| recording }
    controller.define_singleton_method(:current_trashable_actor) { :editor }
    controller.define_singleton_method(:current_trashable_impersonator) { nil }
    controller.define_singleton_method(:sync_redirect_path) { "/back" }

    controller.restore

    assert_equal "/back", URI.parse(controller.response.location).path
    assert_equal "Mix Notes restored", controller.flash[:notice]
    assert_equal :editor, recording.lifecycle_calls[:restore][:actor]
  end

  def test_purge_redirects_with_deleted_notice
    controller = build_controller(RecordingStudioTrashable::RecordingsController, params: { id: "rec-1" })
    recording = FakeRecording.new(title: "Mix Notes")

    controller.define_singleton_method(:find_recording!) { |_id| recording }
    controller.define_singleton_method(:authorize_recording_action!) { |_action, recording:| recording }
    controller.define_singleton_method(:current_trashable_actor) { :editor }
    controller.define_singleton_method(:current_trashable_impersonator) { nil }
    controller.define_singleton_method(:sync_redirect_path) { "/back" }

    controller.purge

    assert_equal "/back", URI.parse(controller.response.location).path
    assert_equal "Mix Notes permantly deleted", controller.flash[:notice]
    assert_equal :editor, recording.lifecycle_calls[:purge][:actor]
  end

  def test_lifecycle_error_renders_async_json_payload
    controller = build_controller(RecordingStudioTrashable::RecordingsController)
    controller.define_singleton_method(:async_response?) { true }

    controller.send(:respond_with_lifecycle_error, "bad request")

    assert_equal 422, controller.response.status
    assert_equal({ "ok" => false, "alert" => "bad request" }, JSON.parse(controller.response.body))
  end

  def test_lifecycle_success_renders_async_json_payload
    controller = build_controller(RecordingStudioTrashable::RecordingsController)
    controller.define_singleton_method(:async_response?) { true }

    controller.send(:respond_with_lifecycle_success, "done")

    assert_equal 200, controller.response.status
    assert_equal({ "ok" => true, "notice" => "done" }, JSON.parse(controller.response.body))
  end

  def test_lifecycle_error_redirects_to_sync_path_for_html_requests
    controller = build_controller(RecordingStudioTrashable::RecordingsController)
    controller.define_singleton_method(:async_response?) { false }
    controller.define_singleton_method(:sync_redirect_path) { "/back" }

    controller.send(:respond_with_lifecycle_error, "bad request")

    assert_equal "/back", URI.parse(controller.response.location).path
    assert_equal "bad request", controller.flash[:alert]
  end

  def test_authorize_mounted_page_redirects_when_unauthorized
    controller = build_controller(RecordingStudioTrashable::ApplicationController)
    controller.define_singleton_method(:recording_studio_trashable_page_authorized?) do |_action, recording: nil|
      _recording = recording
      false
    end
    controller.define_singleton_method(:root_path) { "/root" }
    controller.define_singleton_method(:redirect_back) do |fallback_location:, alert:|
      @redirect_back_arguments = { fallback_location: fallback_location, alert: alert }
      self.response_body = ["redirected"]
    end

    controller.send(:authorize_mounted_page!, :settings, recording: :scope)

    assert_equal(
      {
        fallback_location: "/root",
        alert: "You are not authorized to manage trash here."
      },
      controller.instance_variable_get(:@redirect_back_arguments)
    )
  end

  def test_recording_label_falls_back_to_name_then_type_and_id
    controller = build_controller(RecordingStudioTrashable::ApplicationController)

    named = FakeRecording.new(name: "Reference Assets", recordable_type: "Folder")
    unnamed = FakeRecording.new(id: "1234567890", recordable_type: "Folder")

    assert_equal "Reference Assets", controller.send(:recording_studio_trashable_recording_label, named)
    assert_equal "Folder #12345678", controller.send(:recording_studio_trashable_recording_label, unnamed)
  end

  def test_retention_label_covers_nil_due_and_future_windows
    controller = build_controller(RecordingStudioTrashable::ApplicationController)
    helper_proxy = Object.new
    helper_proxy.define_singleton_method(:l) do |_value, format:|
      format == :long ? "January 10, 2026" : raise("unexpected")
    end
    controller.define_singleton_method(:helpers) { helper_proxy }
    recording = FakeRecording.new

    RecordingStudioTrashable::RetentionPolicy.stub(:purge_at, nil) do
      assert_equal "No automatic purge window",
                   controller.send(:recording_studio_trashable_retention_label, recording, :scope)
    end

    RecordingStudioTrashable::RetentionPolicy.stub(:purge_at, Time.utc(2026, 1, 10, 12, 0, 0)) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, true) do
        assert_equal "Due now", controller.send(:recording_studio_trashable_retention_label, recording, :scope)
      end

      RecordingStudioTrashable::RetentionPolicy.stub(:due?, false) do
        assert_equal "Purges January 10, 2026",
                     controller.send(:recording_studio_trashable_retention_label, recording, :scope)
      end
    end
  end

  def test_retention_settings_update_normalizes_value_and_redirects
    controller = build_controller(
      RecordingStudioTrashable::RetentionSettingsController,
      params: {
        recording_id: "scope-1",
        recording_studio_trashable_retention_setting: { purge_after_days: "14" }
      }
    )
    setting = FakeRetentionSetting.new(save_result: true)

    controller.define_singleton_method(:load_scope_recording) do
      @scope_recording = FakeScopeRecording.new(id: "scope-1")
      @retention_setting = setting
    end
    controller.define_singleton_method(:recording_trash_bin_path) { |scope, _params| "/trash/#{scope.id}" }
    controller.define_singleton_method(:recording_studio_trashable_back_link_params) { { back_path: "/back" } }

    controller.update

    assert_equal({ purge_after_days: 14 }, setting.assigned_attributes)
    assert_equal "/trash/scope-1", URI.parse(controller.response.location).path
    assert_equal "Trash settings updated.", controller.flash[:notice]
  end

  def test_retention_settings_update_renders_edit_when_save_fails
    controller = build_controller(
      RecordingStudioTrashable::RetentionSettingsController,
      params: {
        recording_id: "scope-1",
        recording_studio_trashable_retention_setting: { purge_after_days: "bad" }
      }
    )
    setting = FakeRetentionSetting.new(save_result: false)
    render_call = nil

    controller.define_singleton_method(:load_scope_recording) do
      @scope_recording = FakeScopeRecording.new(id: "scope-1")
      @retention_setting = setting
    end
    controller.define_singleton_method(:render) do |*args, **kwargs|
      render_call = { args: args, kwargs: kwargs }
      response.status = Rack::Utils.status_code(kwargs.fetch(:status)) if kwargs[:status]
    end

    controller.update

    assert_equal({ purge_after_days: nil }, setting.assigned_attributes)
    assert_equal({ args: [:edit], kwargs: { status: :unprocessable_entity } }, render_call)
    assert_equal 422, controller.response.status
  end

  def test_retention_settings_update_stops_after_load_redirect
    controller = build_controller(
      RecordingStudioTrashable::RetentionSettingsController,
      params: {
        recording_id: "scope-1",
        recording_studio_trashable_retention_setting: { purge_after_days: "14" }
      }
    )
    setting = FakeRetentionSetting.new(save_result: true)

    controller.define_singleton_method(:load_scope_recording) do
      @retention_setting = setting
      redirect_to "/blocked"
    end

    controller.update

    assert_equal "/blocked", URI.parse(controller.response.location).path
    assert_nil setting.assigned_attributes
  end

  def test_load_scope_recording_redirects_when_retention_settings_are_disabled
    controller = build_controller(
      RecordingStudioTrashable::RetentionSettingsController,
      params: { recording_id: "scope-1" }
    )
    scope_recording = FakeScopeRecording.new(id: "scope-1")

    controller.define_singleton_method(:find_recording!) { |_id| scope_recording }
    controller.define_singleton_method(:authorize_mounted_page!) { |_action, recording:| recording }
    controller.define_singleton_method(:recording_studio_trashable_retention_settings_enabled?) { false }
    controller.define_singleton_method(:recording_trash_bin_path) { |scope, _params| "/trash/#{scope.id}" }
    controller.define_singleton_method(:recording_studio_trashable_back_link_params) { { back_path: "/back" } }

    controller.send(:load_scope_recording)

    assert_equal "/trash/scope-1", URI.parse(controller.response.location).path
    assert_equal "Retention settings are managed by the application.", controller.flash[:alert]
  end

  def test_trash_bin_show_trims_query_and_pages_sorted_results
    controller = build_controller(
      RecordingStudioTrashable::TrashBinsController,
      params: { recording_id: "scope-1", q: "  Mix  " }
    )
    relation = FakeRelation.new
    scope_recording = FakeScopeRecording.new(id: "scope-1")
    query_call = nil

    controller.define_singleton_method(:find_recording!) { |_id| scope_recording }
    controller.define_singleton_method(:authorize_mounted_page!) { |_action, recording:| recording }
    controller.define_singleton_method(:pagy) { |records, limit:| [:page_meta, [records, limit]] }

    RecordingStudioTrashable.stub(:retention_setting_for, :setting) do
      RecordingStudioTrashable::SubtreeQuery.stub(:trashed_recordings_for_query, lambda { |recording, query:|
        query_call = [recording, query]
        relation
      }) do
        controller.show
      end
    end

    assert_equal [scope_recording, "Mix"], query_call
    assert_equal [{ trashed_at: :desc, id: :desc }], relation.reorder_arguments
    assert_equal "Mix", controller.instance_variable_get(:@search_query)
    assert_equal :setting, controller.instance_variable_get(:@retention_setting)
    assert_equal :page_meta, controller.instance_variable_get(:@pagy)
    assert_equal [relation, 25], controller.instance_variable_get(:@trashed_recordings)
  end

  def test_fallback_redirect_path_prefers_return_to_recording_then_request_scope_then_root
    controller = build_controller(
      RecordingStudioTrashable::RecordingsController,
      params: { return_to_recording_id: "scope-1", recording_id: "scope-2" }
    )
    controller.define_singleton_method(:recording_trash_bin_path) do |scope_id, _params|
      "/trash/#{scope_id}"
    end
    controller.define_singleton_method(:recording_studio_trashable_back_link_params) { { back_path: "/back" } }
    controller.define_singleton_method(:root_path) { "/root" }

    assert_equal "/trash/scope-1", controller.send(:fallback_redirect_path)

    controller = build_controller(RecordingStudioTrashable::RecordingsController, params: { recording_id: "scope-2" })
    controller.define_singleton_method(:recording_trash_bin_path) { |scope_id, _params| "/trash/#{scope_id}" }
    controller.define_singleton_method(:recording_studio_trashable_back_link_params) { { back_path: "/back" } }
    controller.define_singleton_method(:root_path) { "/root" }

    assert_equal "/trash/scope-2", controller.send(:fallback_redirect_path)

    controller = build_controller(RecordingStudioTrashable::RecordingsController)
    controller.define_singleton_method(:root_path) { "/root" }

    assert_equal "/root", controller.send(:fallback_redirect_path)
  end

  private

  def build_controller(controller_class, params: {})
    controller = controller_class.new
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new

    request.set_header("action_dispatch.request.parameters", params.stringify_keys)
    request.set_header("action_dispatch.request_id", "req-123")
    request.set_header("action_dispatch.request.flash_hash", ActionDispatch::Flash::FlashHash.new)
    request.set_header("rack.session", {})

    controller.set_request!(request)
    controller.set_response!(response)
    controller.define_singleton_method(:params) { ActionController::Parameters.new(params) }

    controller
  end
end
