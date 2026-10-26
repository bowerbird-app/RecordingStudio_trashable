# frozen_string_literal: true

require "test_helper"
require "action_controller"

class LayoutConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioTrashable::Configuration.new
    @previous_trashable = RecordingStudioTrashable.instance_variable_get(:@configuration)
    @previous_layout = RecordingStudio.configuration.layout
    RecordingStudioTrashable.instance_variable_set(:@configuration, @configuration)
  end

  def teardown
    RecordingStudioTrashable.instance_variable_set(:@configuration, @previous_trashable)
    RecordingStudio.configuration.layout = @previous_layout
  end

  def test_layout_defaults_to_nil
    assert_nil @configuration.layout
    assert_nil @configuration.to_h.fetch(:layout)
  end

  def test_nil_layout_falls_through_to_recording_studio_then_the_default_name
    RecordingStudio.configuration.layout = nil

    assert_equal "recording_studio/default_layout", probe.recording_studio_resolved_layout

    RecordingStudio.configuration.layout = "host_pages"
    assert_equal "host_pages", probe.recording_studio_resolved_layout
  end

  def test_string_layout_is_used_as_the_layout_name
    @configuration.layout = "trashable_pages"

    assert_equal "trashable_pages", probe.recording_studio_resolved_layout
  end

  def test_false_layout_renders_no_layout
    @configuration.layout = false

    assert_equal false, probe.recording_studio_resolved_layout
  end

  def test_keyword_callable_receives_the_controller
    @configuration.layout = ->(controller:) { controller.class.name }

    assert_equal "TrashableLayoutProbeController", probe.recording_studio_resolved_layout
  end

  def test_invalid_layout_values_raise_argument_error
    assert_raises(ArgumentError) { @configuration.layout = "" }
    assert_raises(ArgumentError) { @configuration.layout = 1 }
    assert_raises(ArgumentError) { @configuration.layout = ->(controller) { "pages" } }
    assert_raises(ArgumentError) { @configuration.layout = -> { "pages" } }
  end

  def test_controllers_do_not_hardcode_a_recording_studio_layout
    gem_root = File.expand_path("..", __dir__)
    dummy_root = File.expand_path("dummy", __dir__)

    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(gem_root)
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(dummy_root)
  end

  private

  def probe
    TrashableLayoutProbeController.new
  end
end

class TrashableLayoutProbeController < ActionController::Base
  include RecordingStudio::ControllerLayout

  recording_studio_layout { RecordingStudioTrashable.configuration.layout }
end
