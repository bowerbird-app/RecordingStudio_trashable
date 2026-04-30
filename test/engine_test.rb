# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioTrashable.instance_variable_get(:@configuration)
    RecordingStudioTrashable.instance_variable_set(:@configuration, RecordingStudioTrashable::Configuration.new)
  end

  def teardown
    RecordingStudioTrashable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioTrashable.configuration.hooks.before_initialize { before_called = true }
    RecordingStudioTrashable.configuration.hooks.after_initialize { after_called = true }

    find_initializer("recording_studio_trashable.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_trashable.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_yaml_and_x_configuration
    xcfg = Struct.new(:recording_studio_trashable).new({ default_purge_after_days: 45 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { accessible_integration_enabled: false }
      end
    end.new(app_config)

    find_initializer("recording_studio_trashable.load_config").block.call(app)

    assert_equal false, RecordingStudioTrashable.configuration.accessible_integration_enabled
    assert_equal 45, RecordingStudioTrashable.configuration.default_purge_after_days
  end

  def test_routes_are_drawn_under_engine_namespace
    routes = File.read(File.expand_path("../config/routes.rb", __dir__))

    assert_includes routes, 'resource :trash_bin'
    assert_includes routes, 'resource :retention_setting'
    assert_includes routes, 'patch :restore'
    assert_includes routes, 'delete :purge'
  end

  private

  def find_initializer(name)
    RecordingStudioTrashable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
