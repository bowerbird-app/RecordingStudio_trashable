# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  class FakeConfigWithImportmap
    attr_reader :importmap, :assets

    def initialize
      @importmap = Struct.new(:paths).new([])
      @assets = Struct.new(:paths).new([])
    end
  end

  class FakeXConfig
    def initialize(values)
      @values = values
    end

    def each_pair(&)
      @values.each_pair(&)
    end
  end

  class FakeLogger
    attr_reader :messages

    def initialize
      @messages = []
    end

    def debug
      @messages << yield
    end
  end

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
    xcfg = Struct.new(:recording_studio_trashable).new(
      { default_include_children: true, default_purge_after_days: 45, allow_user_retention_settings: true }
    )
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { accessible_integration_enabled: false }
      end
    end.new(app_config)

    find_initializer("recording_studio_trashable.load_config").block.call(app)

    assert_equal false, RecordingStudioTrashable.configuration.accessible_integration_enabled
    assert_equal true, RecordingStudioTrashable.configuration.default_include_children
    assert_equal 45, RecordingStudioTrashable.configuration.default_purge_after_days
    assert_equal true, RecordingStudioTrashable.configuration.allow_user_retention_settings
  end

  def test_importmap_initializer_registers_engine_assets_when_supported
    app = Struct.new(:config).new(FakeConfigWithImportmap.new)

    find_initializer("recording_studio_trashable.importmap").block.call(app)

    assert_includes app.config.importmap.paths, RecordingStudioTrashable::Engine.root.join("config/importmap.rb")
    assert_includes app.config.assets.paths, RecordingStudioTrashable::Engine.root.join("app/javascript")
  end

  def test_importmap_initializer_skips_apps_without_importmap_support
    assets = Struct.new(:paths).new([])
    app = Struct.new(:config).new(Struct.new(:assets).new(assets))

    find_initializer("recording_studio_trashable.importmap").block.call(app)

    assert_empty assets.paths
  end

  def test_load_yaml_config_logs_and_swallows_configuration_errors
    logger = FakeLogger.new
    app = Object.new
    app.define_singleton_method(:config_for) do |_name|
      raise "broken yaml"
    end

    Rails.stub(:logger, logger) do
      RecordingStudioTrashable::Engine.send(:load_yaml_config, app)
    end

    assert_includes logger.messages.last, "config_for(:recording_studio_trashable)"
    assert_includes logger.messages.last, "broken yaml"
  end

  def test_load_x_config_supports_each_pair_objects
    RecordingStudioTrashable::Engine.send(
      :load_x_config,
      FakeXConfig.new(default_include_children: true, allow_user_retention_settings: true)
    )

    assert_equal true, RecordingStudioTrashable.configuration.default_include_children
    assert_equal true, RecordingStudioTrashable.configuration.allow_user_retention_settings
  end

  def test_load_x_config_logs_and_swallows_errors
    logger = FakeLogger.new
    config = Object.new
    config.define_singleton_method(:to_h) do
      raise "broken x config"
    end

    Rails.stub(:logger, logger) do
      RecordingStudioTrashable::Engine.send(:load_x_config, config)
    end

    assert_includes logger.messages.last, "config.x.recording_studio_trashable"
    assert_includes logger.messages.last, "broken x config"
  end

  def test_routes_are_drawn_under_engine_namespace
    routes = File.read(File.expand_path("../config/routes.rb", __dir__))

    assert_includes routes, "resource :trash_bin"
    assert_includes routes, "resource :trash_settings"
    assert_includes routes, "patch :restore"
    assert_includes routes, "delete :purge"
  end

  private

  def find_initializer(name)
    RecordingStudioTrashable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
