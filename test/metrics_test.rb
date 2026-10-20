# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  Grant = Struct.new(:actor)
  Context = Struct.new(:access_grant)

  def test_metrics_dependency_is_0_3_to_0_5
    gemspec = File.read(File.expand_path("../recording_studio_trashable.gemspec", __dir__))
    root_gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_metrics", ">= 0.3.0", "< 0.6"'
    assert_includes root_gemfile, 'tag: "v0.5.0"'
    assert_includes dummy_gemfile, 'tag: "v0.5.0"'
  end

  def test_engine_registers_metrics_on_reload
    engine = File.read(File.expand_path("../lib/recording_studio_trashable/engine.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_trashable.metrics"'
    assert_includes engine, "config.to_prepare { RecordingStudioTrashable::Metrics.register! }"
  end

  def test_metrics_file_defines_operations_trash_metrics
    source = File.read(File.expand_path("../lib/recording_studio_trashable/metrics.rb", __dir__))

    assert_includes source, "RESOURCE = :trash"
    assert_includes source, "API = :operations"
    assert_includes source, "blast_radius: :site"
    assert_includes source, "dsl.count :in_trash"
    assert_includes source, "dsl.breakdown :in_trash_by_type"
    assert_includes source, "field: :recordable_type"
    assert_includes source, "dsl.timeseries :trashed_over_time"
    assert_includes source, "field: :trashed_at"
    assert_includes source, "Current trash only"
    assert_includes source, "Purged items vanish"
    assert_includes source, "RecordingStudioTrashable::Api::Access.can_view?"
    assert_includes source, "api_authorize:"
  end

  def test_readme_documents_mcp_tool_names_and_timeseries_window
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "`trash-in_trash`"
    assert_includes readme, "`trash-in_trash_by_type`"
    assert_includes readme, "`trash-trashed_over_time`"
    assert_includes readme, "`from`, `to`, and"
    assert_includes readme, "`interval` are arguments on `trash.trashed_over_time` only"
  end

  def test_access_can_view_is_false_without_actor_or_admin_root
    refute RecordingStudioTrashable::Api::Access.can_view?(Context.new(nil))
    refute RecordingStudioTrashable::Api::Access.can_view?(Context.new(Grant.new(:staff)))
  end
end
