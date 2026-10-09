# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  Grant = Struct.new(:actor)
  Context = Struct.new(:access_grant)

  def teardown
    restore_const(:RecordingStudioAdmin)
    restore_const(:RecordingStudioAccessible)
    RecordingStudioMetrics.registry.reset! if defined?(RecordingStudioMetrics)
  end

  def test_engine_registers_metrics_on_reload
    engine = File.read(File.expand_path("../lib/recording_studio_trashable/engine.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_trashable.metrics"'
    assert_includes engine, "config.to_prepare { RecordingStudioTrashable::Metrics.register! }"
  end

  def test_register_defines_operations_trash_metrics
    RecordingStudio.const_set(:Recording, Class.new) unless defined?(RecordingStudio::Recording)
    RecordingStudioMetrics.registry.reset!
    RecordingStudioTrashable::Metrics.register!

    %w[trash.in_trash trash.in_trash_by_type trash.trashed_over_time].each do |identifier|
      definition = RecordingStudioMetrics.find(identifier)
      assert definition, "expected #{identifier}"
      assert_equal :site, definition.blast_radius
      assert_equal [:operations], definition.exposed_apis
      assert_includes definition.description, "Current trash only"
      assert_includes definition.description, "Purged items vanish"
    end

    assert_equal :recordable_type, RecordingStudioMetrics.find("trash.in_trash_by_type").field
    assert_equal :trashed_at, RecordingStudioMetrics.find("trash.trashed_over_time").field
  end

  def test_access_can_view_is_false_without_actor_or_admin_root
    refute RecordingStudioTrashable::Api::Access.can_view?(Context.new(nil))
  end

  def test_access_can_view_allows_staff_on_admin_root
    with_admin_access(authorized: true) do
      assert RecordingStudioTrashable::Api::Access.can_view?(Context.new(Grant.new(:staff)))
    end
  end

  def test_access_can_view_denies_non_admin
    with_admin_access(authorized: false) do
      refute RecordingStudioTrashable::Api::Access.can_view?(Context.new(Grant.new(:member)))
    end
  end

  private

  def with_admin_access(authorized:)
    config = Struct.new(:access_recording_resolver).new(->(_context) { :admin_root })
    admin = Module.new
    admin.define_singleton_method(:configuration) { config }
    accessible = Module.new
    accessible.define_singleton_method(:authorized?) { |**| authorized }

    swap_const(:RecordingStudioAdmin, admin)
    swap_const(:RecordingStudioAccessible, accessible)
    yield
  end

  def swap_const(name, replacement)
    @original_consts ||= {}
    @original_consts[name] = Object.const_defined?(name, false) ? Object.const_get(name, false) : :__missing__
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, replacement)
  end

  def restore_const(name)
    return unless @original_consts&.key?(name)

    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    original = @original_consts.delete(name)
    Object.const_set(name, original) unless original == :__missing__
  end
end
