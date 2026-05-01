# frozen_string_literal: true

require "test_helper"

class RecordingStudioTrashableTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioTrashable.instance_variable_get(:@configuration)
    RecordingStudioTrashable.instance_variable_set(:@configuration, RecordingStudioTrashable::Configuration.new)
  end

  def teardown
    RecordingStudioTrashable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_version_exists
    refute_nil RecordingStudioTrashable::VERSION
  end

  def test_version_matches_latest_changelog_release
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))

    assert_includes changelog, "## [#{RecordingStudioTrashable::VERSION}]"
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudioTrashable::Engine
  end

  def test_page_capability_alias_is_registered
    assert_equal RecordingStudio::Trashable::Capabilities::Trashable, RecordingStudio::Capabilities::Trashable
  end

  def test_dummy_sidebar_mentions_showcase_pages_and_trash_bins
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    source = File.read(sidebar_path)

    assert_includes source, "main_app.root_path"
    assert_includes source, "main_app.showcase_path"
    assert_includes source, "main_app.destroy_user_session_path"
    assert_includes source, "Workspace trash bin"
    assert_includes source, "Project trash bin"
    assert_includes source, "Adding to a recordable"
    assert_includes source, "Cascading"
    assert_includes source, "Methods"
  end

  def test_dummy_current_supports_actor_and_impersonator
    current_model = File.read(File.expand_path("dummy/app/models/current.rb", __dir__))

    assert_includes current_model, "attribute :actor, :impersonator"
  end

  def test_configure_and_allow_user_retention_settings_follow_configuration
    refute RecordingStudioTrashable.allow_user_retention_settings?

    yielded_configuration = nil
    RecordingStudioTrashable.configure do |configuration|
      yielded_configuration = configuration
      configuration.allow_user_retention_settings = true
    end

    assert_same RecordingStudioTrashable.configuration, yielded_configuration
    assert RecordingStudioTrashable.allow_user_retention_settings?
  end

  def test_current_impersonator_delegates_to_authorization
    RecordingStudioTrashable::Authorization.stub(:current_impersonator, :admin_user) do
      assert_equal :admin_user, RecordingStudioTrashable.current_impersonator(controller: :controller)
    end
  end

  def test_retention_setting_for_delegates_to_the_model
    recording = Object.new
    retention_setting_defined = RecordingStudioTrashable.const_defined?(:RetentionSetting, false)

    unless retention_setting_defined
      RecordingStudioTrashable.const_set(:RetentionSetting, Class.new do
        def self.find_or_initialize_by(*) = nil
      end)
    end

    RecordingStudioTrashable::RetentionSetting.stub(:find_or_initialize_by, :setting) do
      assert_equal :setting, RecordingStudioTrashable.retention_setting_for(recording)
    end
  ensure
    RecordingStudioTrashable.send(:remove_const, :RetentionSetting) unless retention_setting_defined
  end

  def test_capability_options_for_normalizes_supported_type_inputs
    type_class = Class.new
    type_class.define_singleton_method(:name) { "ClassType" }
    type_record = Struct.new(:recordable_type).new("RecordableType")

    requested_types = []
    capability_lookup = lambda do |_capability, for_type:|
      requested_types << for_type
      { "include_children" => true }
    end

    RecordingStudio.stub(:capability_options, capability_lookup) do
      assert_equal({ include_children: true }, RecordingStudioTrashable.capability_options_for("StringType"))
      assert_equal({ include_children: true }, RecordingStudioTrashable.capability_options_for(:symbol_type))
      assert_equal({ include_children: true }, RecordingStudioTrashable.capability_options_for(type_class))
      assert_equal({ include_children: true }, RecordingStudioTrashable.capability_options_for(type_record))
      assert_equal({ include_children: true }, RecordingStudioTrashable.capability_options_for(Object.new))
    end

    assert_equal %w[StringType symbol_type ClassType RecordableType Object], requested_types
    assert_equal({}, RecordingStudioTrashable.capability_options_for(nil))

    RecordingStudio.stub(:capability_options, ->(*) { raise NoMethodError, "missing capability" }) do
      assert_equal({}, RecordingStudioTrashable.capability_options_for("BrokenType"))
    end
  end

  def test_include_children_prefers_explicit_flag_then_capability_config_and_global_defaults
    assert RecordingStudioTrashable.include_children?(recording: :recording, include_children: true)
    refute RecordingStudioTrashable.include_children?(recording: :recording, include_children: false)

    RecordingStudioTrashable.stub(:capability_options_for, { include_children: true }) do
      assert RecordingStudioTrashable.include_children?(recording: :recording)
    end

    RecordingStudioTrashable.configuration.default_include_children = true
    RecordingStudioTrashable.stub(:capability_options_for, {}) do
      assert RecordingStudioTrashable.include_children?(recording: :recording)
    end

    RecordingStudioTrashable.configuration.default_include_children = nil
    studio_configuration = Struct.new(:include_children).new(true)
    RecordingStudioTrashable.stub(:capability_options_for, {}) do
      RecordingStudio.stub(:configuration, studio_configuration) do
        assert RecordingStudioTrashable.include_children?(recording: :recording)
      end
    end

    RecordingStudioTrashable.stub(:capability_options_for, {}) do
      RecordingStudio.stub(:configuration, Struct.new(:include_children).new(false)) do
        refute RecordingStudioTrashable.include_children?(recording: :recording)
      end
    end
  end

  def test_purge_due_recordings_builds_a_purger_and_returns_its_result
    purger_result = Object.new
    purger = Struct.new(:result) do
      def purge! = result
    end.new(purger_result)
    captured_arguments = nil

    RecordingStudioTrashable::RetentionPurger.stub(:new, lambda { |**kwargs|
      captured_arguments = kwargs
      purger
    }) do
      result = RecordingStudioTrashable.purge_due_recordings(
        scope_recording: :scope,
        actor: :actor,
        impersonator: :impersonator,
        as_of: Time.utc(2026, 1, 1),
        metadata: { source: :test }
      )

      assert_same purger_result, result
    end

    assert_equal(
      {
        scope_recording: :scope,
        actor: :actor,
        impersonator: :impersonator,
        as_of: Time.utc(2026, 1, 1),
        metadata: { source: :test }
      },
      captured_arguments
    )
  end
end
