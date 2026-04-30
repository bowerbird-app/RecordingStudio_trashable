# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  DummyController = Struct.new(:current_user)

  def setup
    @original_configuration = RecordingStudioTrashable.instance_variable_get(:@configuration)
    RecordingStudioTrashable.instance_variable_set(:@configuration, RecordingStudioTrashable::Configuration.new)
  end

  def teardown
    RecordingStudioTrashable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_defaults_to_allow_when_accessible_is_unavailable
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
end
