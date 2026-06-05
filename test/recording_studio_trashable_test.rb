# frozen_string_literal: true

require "test_helper"

class RecordingStudioTrashableTest < Minitest::Test
  FakeSweepResult = Struct.new(:purged_recordings, :skipped_recordings, :would_purge_recordings, keyword_init: true)

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

  def test_dummy_sidebar_mentions_showcase_pages
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    source = File.read(sidebar_path)

    assert_includes source, "main_app.root_path"
    assert_includes source, "main_app.showcase_path"
    assert_includes source, "main_app.destroy_user_session_path"
    refute_includes source, "Workspace trash bin"
    refute_includes source, "Project trash bin"
    assert_includes source, "Adding to a recordable"
    assert_includes source, "Trash cans"
    assert_includes source, "Methods"
  end

  def test_dummy_current_supports_actor_and_impersonator
    current_model = File.read(File.expand_path("dummy/app/models/current.rb", __dir__))

    assert_includes current_model, "attribute :actor, :impersonator"
  end

  def test_dummy_recordables_declare_recording_studio_3_hierarchy
    assert_dummy_model_includes("workspace.rb", 'recording_studio_recordable label: "Workspace"')
    assert_dummy_model_includes("workspace.rb", "root: true")

    assert_dummy_model_includes("project.rb", 'recording_studio_recordable label: "Project"')
    assert_dummy_model_includes("project.rb", 'plural_label: "Projects"')
    assert_dummy_model_includes("project.rb", "root: false")
    assert_dummy_model_matches("project.rb", /allowed_parent_types:\s*\[\s*"Workspace"\s*\]/)

    assert_dummy_model_includes("folder.rb", 'recording_studio_recordable label: "Folder"')
    assert_dummy_model_includes("folder.rb", 'plural_label: "Folders"')
    assert_dummy_model_includes("folder.rb", "root: false")
    assert_dummy_model_includes("folder.rb", "allowed_parent_types: %w[Workspace Project Folder]")

    assert_dummy_model_includes("page.rb", 'recording_studio_recordable label: "Page"')
    assert_dummy_model_includes("page.rb", 'plural_label: "Pages"')
    assert_dummy_model_includes("page.rb", "root: false")
    assert_dummy_model_includes("page.rb", "allowed_parent_types: %w[Workspace Project Folder Page]")
  end

  def test_dummy_page_remains_the_only_trashable_recordable
    assert_dummy_model_includes("page.rb", "include RecordingStudio::Capabilities::Trashable.to")

    %w[workspace.rb project.rb folder.rb].each do |model_file|
      refute_includes dummy_model_source(model_file), "RecordingStudio::Capabilities::Trashable"
    end
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
      { "purge_after_days" => 14 }
    end

    RecordingStudio.stub(:capability_options, capability_lookup) do
      assert_equal({ purge_after_days: 14 }, RecordingStudioTrashable.capability_options_for("StringType"))
      assert_equal({ purge_after_days: 14 }, RecordingStudioTrashable.capability_options_for(:symbol_type))
      assert_equal({ purge_after_days: 14 }, RecordingStudioTrashable.capability_options_for(type_class))
      assert_equal({ purge_after_days: 14 }, RecordingStudioTrashable.capability_options_for(type_record))
      assert_equal({ purge_after_days: 14 }, RecordingStudioTrashable.capability_options_for(Object.new))
    end

    assert_equal %w[StringType symbol_type ClassType RecordableType Object], requested_types
    assert_equal({}, RecordingStudioTrashable.capability_options_for(nil))

    RecordingStudio.stub(:capability_options, ->(*) { raise NoMethodError, "missing capability" }) do
      assert_equal({}, RecordingStudioTrashable.capability_options_for("BrokenType"))
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
        metadata: { source: :test },
        dry_run: false
      },
      captured_arguments
    )
  end

  def test_purge_due_recordings_passes_dry_run_to_purger
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
        dry_run: true
      )

      assert_same purger_result, result
    end

    assert_equal true, captured_arguments.fetch(:dry_run)
  end

  def test_purge_due_recordings_for_all_scopes_aggregates_results_using_retention_purge_resolvers
    scope_recordings = %i[workspace project]
    as_of = Time.utc(2026, 1, 2)
    captured_arguments = []
    results = [
      FakeSweepResult.new(purged_recordings: [:first], skipped_recordings: [:skip_first], would_purge_recordings: []),
      FakeSweepResult.new(purged_recordings: [:second], skipped_recordings: [], would_purge_recordings: [])
    ]

    RecordingStudioTrashable.configure do |config|
      config.retention_purge_actor_resolver = -> { :system_actor }
      config.retention_purge_impersonator_resolver = -> { :system_impersonator }
    end

    RecordingStudioTrashable.stub(:purge_due_recordings, lambda { |**kwargs|
      captured_arguments << kwargs
      results.shift
    }) do
      result = RecordingStudioTrashable.purge_due_recordings_for_all_scopes(
        scope_recordings: scope_recordings,
        as_of: as_of,
        metadata: { source: :job }
      )

      assert_equal scope_recordings, result.scope_recordings
      assert_equal %i[first second], result.purged_recordings
      assert_equal [:skip_first], result.skipped_recordings
      assert_empty result.would_purge_recordings
    end

    assert_equal(
      [
        {
          scope_recording: :workspace,
          actor: :system_actor,
          impersonator: :system_impersonator,
          as_of: as_of,
          metadata: { source: :job },
          dry_run: false
        },
        {
          scope_recording: :project,
          actor: :system_actor,
          impersonator: :system_impersonator,
          as_of: as_of,
          metadata: { source: :job },
          dry_run: false
        }
      ],
      captured_arguments
    )
  end

  def test_root_scope_recordings_returns_top_level_recordings
    relation = Object.new
    scope_recordings = %i[root_a root_b]
    recording_defined = RecordingStudio.const_defined?(:Recording, false)
    original_recording = RecordingStudio.const_get(:Recording) if recording_defined

    relation.define_singleton_method(:where) do |conditions|
      raise "unexpected conditions" unless conditions == { parent_recording_id: nil }

      self
    end
    relation.define_singleton_method(:reorder) do |*args|
      raise "unexpected order" unless args == [{ created_at: :asc }]

      self
    end
    relation.define_singleton_method(:to_a) { scope_recordings }

    RecordingStudio.const_set(:Recording, Class.new) unless recording_defined
    RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_including_trashed) { relation }

    assert_equal scope_recordings, RecordingStudioTrashable.root_scope_recordings
  ensure
    if recording_defined
      RecordingStudio.const_set(:Recording, original_recording)
    elsif RecordingStudio.const_defined?(:Recording, false)
      RecordingStudio.send(:remove_const, :Recording)
    end
  end

  private

  def assert_dummy_model_includes(model_file, expected)
    assert_includes dummy_model_source(model_file), expected
  end

  def assert_dummy_model_matches(model_file, expected)
    assert_match expected, dummy_model_source(model_file)
  end

  def dummy_model_source(model_file)
    File.read(File.expand_path("dummy/app/models/#{model_file}", __dir__))
  end
end
