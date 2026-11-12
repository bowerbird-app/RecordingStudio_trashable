# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_gemspec_does_not_depend_on_recording_studio_api
    gemspec = File.read(File.expand_path("recording_studio_trashable.gemspec", ROOT))

    refute_includes gemspec, "recording_studio_api"
  end

  def test_register_is_a_no_op_without_recording_studio_api
    skip "Recording Studio API is loaded" if defined?(::RecordingStudioApi)

    RecordingStudioTrashable::Api.register!
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioTrashable::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_trashable.api"
    assert_includes names, "recording_studio_trashable.metrics"
  end

  def test_metrics_stay_on_operations
    source = File.read(File.expand_path("lib/recording_studio_trashable/metrics.rb", ROOT))

    assert_includes source, "RecordingStudioTrashable::Api::Access.can_view?"
    assert_includes source, "API = :operations"
    refute_includes source, "register_capability_action"
  end
end
