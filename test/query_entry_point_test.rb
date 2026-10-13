# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class QueryEntryPointTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  QUERY_PROBE = <<~'RUBY'
    # frozen_string_literal: true

    require "bundler/setup"
    $LOAD_PATH.unshift File.expand_path("lib", ENV.fetch("TRASHABLE_ROOT"))

    require "rails"
    require "active_support/core_ext/object/blank"
    require "recording_studio_trashable/query"

    loaded = $LOADED_FEATURES.map { |path| path.tr("\\", "/") }

    class ProbeConnection
      def quote_table_name(name) = %("#{name}")
      def quote_column_name(name) = %("#{name}")
    end

    class ProbeRecording
      class << self
        def table_name = "recording_studio_recordings"
        def connection = @connection ||= ProbeConnection.new

        def scope(name, body)
          define_singleton_method(name) { |*args| instance_exec(*args, &body) }
        end
      end

      include RecordingStudioTrashable::RecordingScopes

      attr_accessor :trashed_at

      def initialize(trashed_at: nil)
        @trashed_at = trashed_at
      end

      def update_columns(attributes)
        self.trashed_at = attributes[:trashed_at] if attributes.key?(:trashed_at)
        attributes
      end
    end

    results = {
      "engine_defined" => defined?(RecordingStudioTrashable::Engine) ? "yes" : "no",
      "copy_helper_defined" => defined?(RecordingStudioTrashable::CopyHelper) ? "yes" : "no",
      "metrics_module_defined" => defined?(RecordingStudioTrashable::Metrics) ? "yes" : "no",
      "flat_pack_defined" => defined?(FlatPack) ? "yes" : "no",
      "recording_studio_metrics_defined" => defined?(RecordingStudioMetrics) ? "yes" : "no",
      "capability_registered" => RecordingStudio.registered_capabilities.key?(:trashable) ? "yes" : "no",
      "scopes_module_loaded" => defined?(RecordingStudioTrashable::RecordingScopes) ? "yes" : "no",
      "flat_pack_required" => loaded.any? { |path| path.include?("/flat_pack") || path.end_with?("/flat_pack.rb") } ? "yes" : "no",
      "metrics_gem_required" => loaded.any? { |path| path.include?("recording_studio_metrics") } ? "yes" : "no",
      "engine_required" => loaded.any? { |path| path.end_with?("/recording_studio_trashable/engine.rb") } ? "yes" : "no",
      "capabilities_required" => loaded.any? { |path|
        path.end_with?("/recording_studio/trashable/capabilities/trashable.rb")
      } ? "yes" : "no",
      "main_required" => loaded.any? { |path| path.end_with?("/lib/recording_studio_trashable.rb") } ? "yes" : "no",
      "kept_sql" => ProbeRecording.recording_studio_trashable_kept_sql("child"),
      "trashed_sql" => ProbeRecording.recording_studio_trashable_trashed_sql("child"),
      "kept_predicate" => ProbeRecording.new(trashed_at: nil).recording_studio_trashable_kept? ? "yes" : "no",
      "trashed_predicate" => ProbeRecording.new(trashed_at: Time.now).recording_studio_trashable_trashed? ? "yes" : "no",
      "capability_methods_on_scopes" => %i[
        recording_studio_trashable_trash!
        recording_studio_trashable_restore!
        recording_studio_trashable_purge!
      ].any? { |name| RecordingStudioTrashable::RecordingScopes.instance_methods.include?(name) } ? "yes" : "no"
    }

    voided = ProbeRecording.new(trashed_at: nil)
    RecordingStudioTrashable.void_recording!(voided, time: Time.utc(2026, 10, 13))
    results["void_wrote"] = voided.trashed_at == Time.utc(2026, 10, 13) ? "yes" : "no"

    results.each { |key, value| puts "#{key}=#{value}" }
  RUBY

  def test_query_require_exposes_helpers_without_engine_side_effects
    output, status = run_probe(QUERY_PROBE)

    assert_predicate status, :success?, output
    assert_equal "yes", probe_value(output, "scopes_module_loaded")
    assert_equal "no", probe_value(output, "engine_defined")
    assert_equal "no", probe_value(output, "copy_helper_defined")
    assert_equal "no", probe_value(output, "metrics_module_defined")
    assert_equal "no", probe_value(output, "flat_pack_defined")
    assert_equal "no", probe_value(output, "recording_studio_metrics_defined")
    assert_equal "no", probe_value(output, "capability_registered")
    assert_equal "no", probe_value(output, "flat_pack_required")
    assert_equal "no", probe_value(output, "metrics_gem_required")
    assert_equal "no", probe_value(output, "engine_required")
    assert_equal "no", probe_value(output, "capabilities_required")
    assert_equal "no", probe_value(output, "main_required")
    assert_equal "no", probe_value(output, "capability_methods_on_scopes")
    assert_equal '"child"."trashed_at" IS NULL', probe_value(output, "kept_sql")
    assert_equal '"child"."trashed_at" IS NOT NULL', probe_value(output, "trashed_sql")
    assert_equal "yes", probe_value(output, "kept_predicate")
    assert_equal "yes", probe_value(output, "trashed_predicate")
    assert_equal "yes", probe_value(output, "void_wrote")
  end

  def test_default_require_keeps_full_engine_surface
    assert defined?(RecordingStudioTrashable::Engine)
    assert defined?(RecordingStudioTrashable::CopyHelper)
    assert defined?(RecordingStudioTrashable::Metrics)
    assert defined?(FlatPack)
    assert RecordingStudio.registered_capabilities.key?(:trashable)

    engine_source = File.read(File.expand_path("lib/recording_studio_trashable/engine.rb", ROOT))
    importmap_source = File.read(File.expand_path("config/importmap.rb", ROOT))
    main_source = File.read(File.expand_path("lib/recording_studio_trashable.rb", ROOT))

    assert_includes engine_source, 'initializer "recording_studio_trashable.importmap"'
    assert_includes engine_source, 'app.config.importmap.paths << Engine.root.join("config/importmap.rb")'
    assert_includes engine_source, 'app.config.assets.paths << Engine.root.join("app/javascript")'
    assert_includes engine_source, "include RecordingStudioTrashable::CopyHelper"
    assert_includes engine_source, "RecordingStudioTrashable::Metrics.register!"
    assert_includes importmap_source,
                    'pin_all_from RecordingStudioTrashable::Engine.root.join("app/javascript/recording_studio_trashable/controllers")'
    assert_includes main_source, 'require "flat_pack"'
    assert_includes main_source, 'require "recording_studio_trashable/metrics"'
    assert_includes main_source, 'require "recording_studio/trashable/capabilities/trashable"'
    assert_includes main_source, 'require "recording_studio_trashable/query"'

    registration = RecordingStudio.registered_capabilities.fetch(:trashable)
    assert_equal "recording_studio_trashable", registration.fetch(:source)
    methods = registration.fetch(:recording_methods)
    assert_includes methods.instance_methods, :recording_studio_trashable_trash!
    assert_includes methods.instance_methods, :recording_studio_trashable_restore!
    assert_includes methods.instance_methods, :recording_studio_trashable_purge!
  end

  def test_query_and_default_sql_helpers_match
    scoped = Class.new do
      class << self
        def table_name = "recording_studio_recordings"

        def connection
          @connection ||= Class.new do
            def quote_table_name(name) = %("#{name}")
            def quote_column_name(name) = %("#{name}")
          end.new
        end

        def scope(name, body)
          define_singleton_method(name) { |*args| instance_exec(*args, &body) }
        end
      end

      include RecordingStudioTrashable::RecordingScopes
    end

    assert_equal '"child"."trashed_at" IS NULL',
                 scoped.recording_studio_trashable_kept_sql("child")
    assert_equal '"child"."trashed_at" IS NOT NULL',
                 scoped.recording_studio_trashable_trashed_sql("child")
  end

  private

  def run_probe(script)
    env = {
      "BUNDLE_GEMFILE" => File.expand_path("Gemfile", ROOT),
      "TRASHABLE_ROOT" => ROOT,
      "RUBYOPT" => ""
    }
    Open3.capture2e(env, RbConfig.ruby, "-e", script, chdir: ROOT)
  end

  def probe_value(output, key)
    line = output.lines.map(&:chomp).find { |entry| entry.start_with?("#{key}=") }
    refute_nil line, "missing probe key #{key.inspect} in:\n#{output}"
    line.delete_prefix("#{key}=")
  end
end
