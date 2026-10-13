# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class QueryEntryPointTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  QUERY_HOST_ROOT = File.expand_path("query_host", __dir__)
  DUMMY_GEMFILE = File.expand_path("dummy/Gemfile", __dir__)

  SIDE_EFFECT_PROBE = <<~'RUBY'
    # frozen_string_literal: true

    require "bundler/setup"
    $LOAD_PATH.unshift File.expand_path("lib", ENV.fetch("TRASHABLE_ROOT"))

    require "rails"
    require "recording_studio_trashable/query"

    loaded = $LOADED_FEATURES.map { |path| path.tr("\\", "/") }

    {
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
      "reloader_prepare_hook" => (
        defined?(ActiveSupport::Reloader) &&
          File.read(File.expand_path("lib/recording_studio_trashable/query.rb", ENV.fetch("TRASHABLE_ROOT")))
              .include?("ActiveSupport::Reloader.to_prepare")
      ) ? "yes" : "no",
      "capability_methods_on_scopes" => %i[
        recording_studio_trashable_trash!
        recording_studio_trashable_restore!
        recording_studio_trashable_purge!
      ].any? { |name| RecordingStudioTrashable::RecordingScopes.instance_methods.include?(name) } ? "yes" : "no"
    }.each { |key, value| puts "#{key}=#{value}" }
  RUBY

  QUERY_HOST_PROBE = <<~'RUBY'
    # frozen_string_literal: true

    ENV["RAILS_ENV"] = "test"
    require "bundler/setup"

    require "rails"
    require "active_record/railtie"
    require "action_controller/railtie"

    raise "Recording already defined before query require" if defined?(RecordingStudio::Recording)

    require "recording_studio_trashable/query"

    puts "after_require_recording_defined=#{defined?(RecordingStudio::Recording) ? 'yes' : 'no'}"

    module QueryHost
      class Application < Rails::Application
        config.root = ENV.fetch("QUERY_HOST_ROOT")
        config.load_defaults 8.1
        config.eager_load = ENV["EAGER_LOAD"] == "1"
        config.cache_classes = false
        config.enable_reloading = true
        config.consider_all_requests_local = true
        config.secret_key_base = "x" * 64
        config.hosts.clear
      end
    end

    Rails.application.initialize!

    loaded = $LOADED_FEATURES.map { |path| path.tr("\\", "/") }

    puts "engine=#{defined?(RecordingStudioTrashable::Engine) ? 'yes' : 'no'}"
    puts "capability=#{RecordingStudio.registered_capabilities.key?(:trashable) ? 'yes' : 'no'}"
    puts "flat_pack=#{defined?(FlatPack) ? 'yes' : 'no'}"
    puts "metrics=#{defined?(RecordingStudioMetrics) ? 'yes' : 'no'}"
    puts "copy_helper=#{defined?(RecordingStudioTrashable::CopyHelper) ? 'yes' : 'no'}"
    puts "trashable_metrics_mod=#{defined?(RecordingStudioTrashable::Metrics) ? 'yes' : 'no'}"
    puts "engine_required=#{loaded.any? { |path| path.end_with?('/recording_studio_trashable/engine.rb') } ? 'yes' : 'no'}"
    puts "main_required=#{loaded.any? { |path| path.end_with?('/lib/recording_studio_trashable.rb') } ? 'yes' : 'no'}"

    recording = RecordingStudio::Recording
    puts "active=#{recording.respond_to?(:recording_studio_trashable_active) ? 'yes' : 'no'}"
    puts "kept_sql_method=#{recording.respond_to?(:recording_studio_trashable_kept_sql) ? 'yes' : 'no'}"
    puts "scopes_included=#{recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes) ? 'yes' : 'no'}"
    if recording.respond_to?(:recording_studio_trashable_kept_sql)
      puts "kept_sql=#{recording.recording_studio_trashable_kept_sql('child')}"
    end

    Rails.application.reloader.reload!

    recording_after = RecordingStudio::Recording
    puts "after_reload_active=#{recording_after.respond_to?(:recording_studio_trashable_active) ? 'yes' : 'no'}"
    puts "after_reload_kept_sql_method=#{recording_after.respond_to?(:recording_studio_trashable_kept_sql) ? 'yes' : 'no'}"
    puts "after_reload_scopes_included=#{recording_after.included_modules.include?(RecordingStudioTrashable::RecordingScopes) ? 'yes' : 'no'}"
    if recording_after.respond_to?(:recording_studio_trashable_kept_sql)
      puts "after_reload_kept_sql=#{recording_after.recording_studio_trashable_kept_sql('child')}"
    end
  RUBY

  def test_query_require_loads_without_engine_side_effects
    output, status = run_probe(SIDE_EFFECT_PROBE, gemfile: File.expand_path("Gemfile", ROOT))

    assert_predicate status, :success?, output
    assert_equal "yes", probe_value(output, "scopes_module_loaded")
    assert_equal "yes", probe_value(output, "reloader_prepare_hook")
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
  end

  def test_query_host_installs_scopes_on_recording_before_and_after_reload
    [0, 1].each do |eager_load|
      output, status = run_probe(
        QUERY_HOST_PROBE,
        gemfile: DUMMY_GEMFILE,
        env: {
          "QUERY_HOST_ROOT" => QUERY_HOST_ROOT,
          "EAGER_LOAD" => eager_load.to_s,
          "DB_HOST" => ENV.fetch("DB_HOST", "localhost"),
          "DB_PORT" => ENV.fetch("DB_PORT", "5432"),
          "DB_USER" => ENV.fetch("DB_USER", "postgres"),
          "DB_PASSWORD" => ENV.fetch("DB_PASSWORD", "postgres"),
          "DB_NAME" => ENV.fetch("DB_NAME", "app_test")
        }
      )

      assert_predicate status, :success?, "eager_load=#{eager_load}\n#{output}"
      assert_equal "no", probe_value(output, "after_require_recording_defined"), output
      assert_equal "no", probe_value(output, "engine"), output
      assert_equal "no", probe_value(output, "capability"), output
      assert_equal "no", probe_value(output, "flat_pack"), output
      assert_equal "no", probe_value(output, "metrics"), output
      assert_equal "no", probe_value(output, "copy_helper"), output
      assert_equal "no", probe_value(output, "trashable_metrics_mod"), output
      assert_equal "no", probe_value(output, "engine_required"), output
      assert_equal "no", probe_value(output, "main_required"), output
      assert_equal "yes", probe_value(output, "active"), output
      assert_equal "yes", probe_value(output, "kept_sql_method"), output
      assert_equal "yes", probe_value(output, "scopes_included"), output
      assert_equal '"child"."trashed_at" IS NULL', probe_value(output, "kept_sql"), output
      assert_equal "yes", probe_value(output, "after_reload_active"), output
      assert_equal "yes", probe_value(output, "after_reload_kept_sql_method"), output
      assert_equal "yes", probe_value(output, "after_reload_scopes_included"), output
      assert_equal '"child"."trashed_at" IS NULL', probe_value(output, "after_reload_kept_sql"), output
    end
  end

  def test_query_source_registers_reloader_prepare_install
    source = File.read(File.expand_path("lib/recording_studio_trashable/query.rb", ROOT))

    assert_includes source, "def install_query_helpers!"
    assert_includes source, "RecordingStudioTrashable.install_query_helpers!"
    assert_includes source, "ActiveSupport::Reloader.to_prepare"
    assert_match(
      /ActiveSupport::Reloader\.to_prepare\s*\{\s*RecordingStudioTrashable\.install_query_helpers!\s*\}/,
      source
    )
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

  def run_probe(script, gemfile:, env: {})
    probe_env = {
      "BUNDLE_GEMFILE" => gemfile,
      "TRASHABLE_ROOT" => ROOT,
      "RUBYOPT" => ""
    }.merge(env)
    Open3.capture2e(probe_env, RbConfig.ruby, "-e", script, chdir: ROOT)
  end

  def probe_value(output, key)
    line = output.lines.map(&:chomp).find { |entry| entry.start_with?("#{key}=") }
    refute_nil line, "missing probe key #{key.inspect} in:\n#{output}"
    line.delete_prefix("#{key}=")
  end
end
