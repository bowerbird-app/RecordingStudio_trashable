# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  DummyController = Struct.new(:current_user)

  class FakeAccessibleAuthorizer
    class << self
      attr_accessor :last_payload

      def authorized?(**payload)
        self.last_payload = payload
        true
      end
    end

    class FakeAllowedAccessibleAuthorizer
      class << self
        attr_accessor :last_payload

        def allowed?(**payload)
          self.last_payload = payload
          true
        end
      end
    end
  end

  class FakeCurrent
    class << self
      attr_accessor :actor, :impersonator
    end
  end

  def setup
    @original_configuration = RecordingStudioTrashable.instance_variable_get(:@configuration)
    RecordingStudioTrashable.instance_variable_set(:@configuration, RecordingStudioTrashable::Configuration.new)
  end

  def teardown
    RecordingStudioTrashable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_defaults_to_deny_when_accessible_is_unavailable
    refute RecordingStudioTrashable.authorized?(action: :trash, actor: nil, recording: Object.new)
  end

  def test_can_explicitly_allow_when_unconfigured
    RecordingStudioTrashable.configure do |config|
      config.allow_unconfigured_authorization = true
    end

    assert RecordingStudioTrashable.authorized?(action: :trash, actor: nil, recording: Object.new)
  end

  def test_uses_custom_authorization_resolver_when_present
    RecordingStudioTrashable.configure do |config|
      config.authorization_resolver = ->(action:, actor:, **) { action == :purge && actor == :admin }
    end

    assert RecordingStudioTrashable.authorized?(action: :purge, actor: :admin, recording: :recording)
    refute RecordingStudioTrashable.authorized?(action: :trash, actor: :admin, recording: :recording)
  end

  def test_current_actor_prefers_custom_resolver_then_current_user
    controller = DummyController.new(:fallback_user)

    RecordingStudioTrashable.configure do |config|
      config.current_actor_resolver = ->(controller:) { controller.current_user.to_s.upcase }
    end

    assert_equal "FALLBACK_USER", RecordingStudioTrashable.current_actor(controller: controller)
  end

  def test_mounted_page_authorized_uses_custom_resolver
    RecordingStudioTrashable.configure do |config|
      config.mounted_page_authorizer = ->(action:, **) { action == :settings }
    end

    assert RecordingStudioTrashable.mounted_page_authorized?(action: :settings, actor: nil, recording: nil)
    refute RecordingStudioTrashable.mounted_page_authorized?(action: :trash_bin, actor: nil, recording: nil)
  end

  def test_authorized_uses_recording_studio_accessible_when_enabled
    RecordingStudioTrashable.configure do |config|
      config.use_recording_studio_accessible = true
      config.authorization_roles = { trash: :edit }
    end
    FakeAccessibleAuthorizer.last_payload = nil

    RecordingStudioTrashable.const_set(:RecordingStudioAccessible, FakeAccessibleAuthorizer)

    assert RecordingStudioTrashable.authorized?(action: :trash, actor: :user, recording: :recording)
    assert_equal(
      { actor: :user, recording: :recording, role: :edit },
      FakeAccessibleAuthorizer.last_payload
    )
  ensure
    if RecordingStudioTrashable.const_defined?(:RecordingStudioAccessible, false)
      RecordingStudioTrashable.send(:remove_const, :RecordingStudioAccessible)
    end
  end

  def test_custom_authorization_resolver_can_abstain_to_accessible_authorizer
    RecordingStudioTrashable.configure do |config|
      config.use_recording_studio_accessible = true
      config.authorization_roles = { trash: :edit }
      config.authorization_resolver = ->(**) {}
    end
    FakeAccessibleAuthorizer.last_payload = nil

    RecordingStudioTrashable.const_set(:RecordingStudioAccessible, FakeAccessibleAuthorizer)

    assert RecordingStudioTrashable.authorized?(action: :trash, actor: :user, recording: :recording)
    assert_equal(
      { actor: :user, recording: :recording, role: :edit },
      FakeAccessibleAuthorizer.last_payload
    )
  ensure
    if RecordingStudioTrashable.const_defined?(:RecordingStudioAccessible, false)
      RecordingStudioTrashable.send(:remove_const, :RecordingStudioAccessible)
    end
  end

  def test_authorized_uses_recording_studio_accessible_allowed_adapter
    RecordingStudioTrashable.configure do |config|
      config.use_recording_studio_accessible = true
      config.authorization_roles = { trash: :edit }
    end
    FakeAllowedAccessibleAuthorizer.last_payload = nil

    RecordingStudioTrashable.const_set(:RecordingStudioAccessible, FakeAllowedAccessibleAuthorizer)

    assert RecordingStudioTrashable.authorized?(action: :trash, actor: :user, recording: :recording)
    assert_equal(
      { actor: :user, recording: :recording, role: :edit },
      FakeAllowedAccessibleAuthorizer.last_payload
    )
  ensure
    if RecordingStudioTrashable.const_defined?(:RecordingStudioAccessible, false)
      RecordingStudioTrashable.send(:remove_const, :RecordingStudioAccessible)
    end
  end

  def test_authorized_does_not_fall_back_to_removed_core_access_check
    RecordingStudioTrashable.configure do |config|
      config.use_recording_studio_accessible = true
      config.authorization_roles = { trash: :edit }
    end

    called = false
    services_was_defined = RecordingStudio.const_defined?(:Services, false)
    original_services = RecordingStudio.const_get(:Services) if services_was_defined
    RecordingStudio.send(:remove_const, :Services) if services_was_defined
    RecordingStudio.const_set(:Services, Module.new)
    RecordingStudio::Services.const_set(:AccessCheck, Class.new do
      define_singleton_method(:allowed?) do |**|
        called = true
        true
      end
    end)

    refute RecordingStudioTrashable.authorized?(action: :trash, actor: :user, recording: :recording)
    refute called
    refute_includes File.read(File.expand_path("../lib/recording_studio_trashable/authorization.rb", __dir__)),
                    "AccessCheck"
  ensure
    if RecordingStudio.const_defined?(:Services, false)
      RecordingStudio.send(:remove_const, :Services)
    end
    RecordingStudio.const_set(:Services, original_services) if services_was_defined
  end

  def test_current_actor_and_impersonator_fall_back_to_current_attributes
    FakeCurrent.actor = :current_actor
    FakeCurrent.impersonator = :current_impersonator
    Object.const_set(:Current, FakeCurrent)

    assert_equal :current_actor, RecordingStudioTrashable.current_actor
    assert_equal :current_impersonator, RecordingStudioTrashable.current_impersonator
  ensure
    Object.send(:remove_const, :Current) if Object.const_defined?(:Current, false)
  end

  def test_current_actor_falls_back_to_controller_current_user
    controller = DummyController.new(:controller_user)

    assert_equal :controller_user, RecordingStudioTrashable.current_actor(controller: controller)
  end

  def test_recordings_controller_uses_action_authorization_for_member_actions
    source = File.read(
      File.expand_path("../app/controllers/recording_studio_trashable/recordings_controller.rb", __dir__)
    )

    assert_includes source, "authorize_recording_action!(action, recording: @recording)"
    assert_includes source, "return if performed?"
    assert_includes(
      source,
      "success_message: -> { \"\#{recording_studio_trashable_recording_label(@recording)} moved to trash\" }"
    )
    assert_includes(
      source,
      "success_message: -> { \"\#{recording_studio_trashable_recording_label(@recording)} restored\" }"
    )
    assert_includes(
      source,
      "success_message: -> { \"\#{recording_studio_trashable_recording_label(@recording)} permanently deleted\" }"
    )
    assert_includes(
      source,
      "resolved_success_message = success_message.respond_to?(:call) ? " \
      "instance_exec(&success_message) : success_message"
    )
    assert_includes source, "respond_with_lifecycle_success(resolved_success_message)"
  end

  def test_recordings_controller_uses_server_owned_lifecycle_metadata
    source = File.read(
      File.expand_path("../app/controllers/recording_studio_trashable/recordings_controller.rb", __dir__)
    )

    assert_includes source, 'source: "recording_studio_trashable_ui"'
    assert_includes source, "request_id: request.request_id"
    refute_includes source, "params[:metadata]"
    refute_includes source, "permit!"
  end
end
