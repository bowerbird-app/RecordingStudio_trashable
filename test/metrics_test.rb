# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  Grant = Struct.new(:actor)
  Context = Struct.new(:access_grant)

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
  end

  def test_access_can_view_is_false_without_actor_or_admin_root
    refute RecordingStudioTrashable::Api::Access.can_view?(Context.new(nil))
    refute RecordingStudioTrashable::Api::Access.can_view?(Context.new(Grant.new(:staff)))
  end
end
