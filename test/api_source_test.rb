# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_register_is_gated_on_recording_studio_api
    source = File.read(File.expand_path("lib/recording_studio_trashable/api.rb", ROOT))
    catalog = File.read(File.expand_path("lib/recording_studio_trashable/api/catalog.rb", ROOT))

    assert_includes source, "defined?(::RecordingStudioApi)"
    assert_includes source, "each_api"
    assert_includes source, "register_capability_action"
    assert_includes source, "api: api_name"
    assert_includes catalog, "reject_unknown: false"
    assert_includes catalog, 'title: "Trash - Restore"'
    refute_includes source, "const_set"
    refute_includes source, "remove_const"
  end

  def test_gemspec_does_not_depend_on_recording_studio_api
    gemspec = File.read(File.expand_path("recording_studio_trashable.gemspec", ROOT))

    refute_includes gemspec, "recording_studio_api"
  end

  def test_metrics_registration_is_unchanged
    source = File.read(File.expand_path("lib/recording_studio_trashable/metrics.rb", ROOT))

    assert_includes source, "RecordingStudioTrashable::Api::Access.can_view?"
    assert_includes source, "API = :operations"
    refute_includes source, "register_capability_action"
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioTrashable::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_trashable.api"
    assert_includes names, "recording_studio_trashable.metrics"
  end

  def test_lifecycle_methods_stay_on_the_capability
    source = File.read(
      File.expand_path("lib/recording_studio/trashable/capabilities/trashable.rb", ROOT)
    )

    assert_includes source, "def recording_studio_trashable_trash!"
    assert_includes source, "def recording_studio_trashable_restore!"
    assert_includes source, "def recording_studio_trashable_purge!"
  end
end
