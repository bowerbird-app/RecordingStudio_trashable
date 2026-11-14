# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class QueryEntryPointTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  QUERY_HOST_ROOT = File.expand_path("query_host", __dir__)
  ROOT_GEMFILE = File.expand_path("../Gemfile", __dir__)

  SIDE_EFFECT_PROBE = <<~'RUBY'
    # frozen_string_literal: true

    require "bundler/setup"
    $LOAD_PATH.unshift File.expand_path("lib", ENV.fetch("TRASHABLE_ROOT"))

    require "rails"
    require "recording_studio_trashable/query"

    loaded = $LOADED_FEATURES.map { |path| path.tr("\\", "/") }
    query_source = File.read(File.expand_path("lib/recording_studio_trashable/query.rb", ENV.fetch("TRASHABLE_ROOT")))

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
      "extend_model_hook" => query_source.include?("extend_model(:recording,") ? "yes" : "no",
      "reloader_prepare_hook" => query_source.include?("ActiveSupport::Reloader.to_prepare") ? "yes" : "no",
      "install_query_helpers" => query_source.include?("install_query_helpers!") ? "yes" : "no",
      "query_only_apply" => (
        query_source.include?("!defined?(RecordingStudioTrashable::Engine)") &&
        query_source.include?("apply_model_extensions!")
      ) ? "yes" : "no",
      "capability_methods_on_scopes" => %i[
        recording_studio_trashable_trash!
        recording_studio_trashable_restore!
        recording_studio_trashable_purge!
      ].any? { |name| RecordingStudioTrashable::RecordingScopes.instance_methods.include?(name) } ? "yes" : "no"
    }.each { |key, value| puts "#{key}=#{value}" }

    before_ids = RecordingStudio.configuration.hooks.model_extensions_for(:recording).map(&:object_id)
    load File.expand_path("lib/recording_studio_trashable/query.rb", ENV.fetch("TRASHABLE_ROOT"))
    after_ids = RecordingStudio.configuration.hooks.model_extensions_for(:recording).map(&:object_id)
    puts "extension_count=#{after_ids.size}"
    puts "extension_ids_stable=#{before_ids == after_ids && before_ids.one? ? 'yes' : 'no'}"
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
    puts "trashed_scope=#{recording.respond_to?(:recording_studio_trashable_trashed) ? 'yes' : 'no'}"
    puts "active=#{recording.respond_to?(:recording_studio_trashable_active) ? 'yes' : 'no'}"
    puts "kept_sql_method=#{recording.respond_to?(:recording_studio_trashable_kept_sql) ? 'yes' : 'no'}"
    puts "scopes_included=#{recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes) ? 'yes' : 'no'}"
    puts "extension_count=#{RecordingStudio.configuration.hooks.model_extensions_for(:recording).size}"
    puts "filter_registered=#{RecordingStudio.unregister_recording_filter(:trashable) ? 'yes' : 'no'}"
    RecordingStudioTrashable::RecordingFilter.register!

    Rails.application.reloader.reload!

    recording_after = RecordingStudio::Recording
    puts "after_reload_trashed_scope=#{recording_after.respond_to?(:recording_studio_trashable_trashed) ? 'yes' : 'no'}"
    puts "after_reload_active=#{recording_after.respond_to?(:recording_studio_trashable_active) ? 'yes' : 'no'}"
    puts "after_reload_kept_sql_method=#{recording_after.respond_to?(:recording_studio_trashable_kept_sql) ? 'yes' : 'no'}"
    puts "after_reload_scopes_included=#{recording_after.included_modules.include?(RecordingStudioTrashable::RecordingScopes) ? 'yes' : 'no'}"
    puts "after_reload_extension_count=#{RecordingStudio.configuration.hooks.model_extensions_for(:recording).size}"
    puts "after_reload_filter_registered=#{RecordingStudio.unregister_recording_filter(:trashable) ? 'yes' : 'no'}"
  RUBY

  # Boot and load Recording first, then require query. Asserts scopes land from the
  # require-time apply before any reload.
  LATE_REQUIRE_QUERY_HOST_PROBE = <<~'RUBY'
    # frozen_string_literal: true

    ENV["RAILS_ENV"] = "test"
    require "bundler/setup"

    require "rails"
    require "active_record/railtie"
    require "action_controller/railtie"
    require "recording_studio"

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

    recording = RecordingStudio::Recording
    puts "pre_query_trashed=#{recording.respond_to?(:recording_studio_trashable_trashed) ? 'yes' : 'no'}"
    puts "pre_query_filter=#{RecordingStudio.unregister_recording_filter(:trashable) ? 'yes' : 'no'}"

    require "recording_studio_trashable/query"

    loaded = $LOADED_FEATURES.map { |path| path.tr("\\", "/") }
    recording = RecordingStudio::Recording
    puts "late_require_trashed=#{recording.respond_to?(:recording_studio_trashable_trashed) ? 'yes' : 'no'}"
    puts "late_require_active=#{recording.respond_to?(:recording_studio_trashable_active) ? 'yes' : 'no'}"
    puts "late_require_kept_sql_method=#{recording.respond_to?(:recording_studio_trashable_kept_sql) ? 'yes' : 'no'}"
    puts "late_require_scopes_included=#{recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes) ? 'yes' : 'no'}"
    puts "late_require_extension_count=#{RecordingStudio.configuration.hooks.model_extensions_for(:recording).size}"
    puts "late_require_filter=#{RecordingStudio.unregister_recording_filter(:trashable) ? 'yes' : 'no'}"
    puts "engine=#{defined?(RecordingStudioTrashable::Engine) ? 'yes' : 'no'}"
    puts "capability=#{RecordingStudio.registered_capabilities.key?(:trashable) ? 'yes' : 'no'}"
    puts "flat_pack=#{defined?(FlatPack) ? 'yes' : 'no'}"
    puts "engine_required=#{loaded.any? { |path| path.end_with?('/recording_studio_trashable/engine.rb') } ? 'yes' : 'no'}"
    puts "main_required=#{loaded.any? { |path| path.end_with?('/lib/recording_studio_trashable.rb') } ? 'yes' : 'no'}"
  RUBY

  FULL_GEM_HOST = <<~RUBY
    class ApplicationController < ActionController::Base
    end

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
  RUBY

  REPORT_RECORDING = <<~'RUBY'
    def report_recording(prefix)
      recording = RecordingStudio::Recording
      ancestry = recording.ancestors.map(&:name)
      scopes_index = ancestry.index("RecordingStudioTrashable::RecordingScopes")
      methods_index = ancestry.index("RecordingStudio::Trashable::Capabilities::Trashable::RecordingMethods")
      puts "#{prefix}_scopes_index=#{scopes_index}"
      puts "#{prefix}_methods_index=#{methods_index}"
      puts "#{prefix}_scopes_included=#{recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes) ? 'yes' : 'no'}"
      puts "#{prefix}_active=#{recording.respond_to?(:recording_studio_trashable_active) ? 'yes' : 'no'}"
      puts "#{prefix}_trashed=#{recording.respond_to?(:recording_studio_trashable_trashed) ? 'yes' : 'no'}"
      registered = RecordingStudio.unregister_recording_filter(:trashable)
      RecordingStudioTrashable::RecordingFilter.register!
      puts "#{prefix}_filter=#{registered ? 'yes' : 'no'}"
      puts "#{prefix}_extension_count=#{RecordingStudio.configuration.hooks.model_extensions_for(:recording).size}"
    end
  RUBY

  # Recording already exists, then the full gem loads. Scopes must land after
  # apply_capabilities!, and stay there across a reload.
  FULL_GEM_LATE_PROBE = <<~RUBY.freeze
    # frozen_string_literal: true

    ENV["RAILS_ENV"] = "test"
    require "bundler/setup"
    require "rails"
    require "active_record/railtie"
    require "action_controller/railtie"
    require "recording_studio"

    #{FULL_GEM_HOST}
    Rails.application.initialize!

    recording = RecordingStudio::Recording
    puts "pre_scopes_included=\#{recording.respond_to?(:recording_studio_trashable_trashed) ? 'yes' : 'no'}"

    require "recording_studio_trashable"

    #{REPORT_RECORDING}
    report_recording("late")
    late_extensions = RecordingStudio.configuration.hooks.model_extensions_for(:recording).map(&:object_id)
    Rails.application.reloader.reload!
    report_recording("after_reload")
    reloaded_extensions = RecordingStudio.configuration.hooks.model_extensions_for(:recording).map(&:object_id)
    puts "extension_ids_stable=\#{late_extensions == reloaded_extensions ? 'yes' : 'no'}"
  RUBY

  def test_query_require_loads_without_engine_side_effects
    output, status = run_probe(SIDE_EFFECT_PROBE, gemfile: ROOT_GEMFILE)

    assert_predicate status, :success?, output
    assert_equal "yes", probe_value(output, "scopes_module_loaded")
    assert_equal "yes", probe_value(output, "extend_model_hook"), output
    assert_equal "no", probe_value(output, "reloader_prepare_hook")
    assert_equal "no", probe_value(output, "install_query_helpers")
    assert_equal "yes", probe_value(output, "query_only_apply")
    assert_equal "1", probe_value(output, "extension_count")
    assert_equal "yes", probe_value(output, "extension_ids_stable")
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
      output, status = run_query_host_probe(QUERY_HOST_PROBE, eager_load: eager_load)

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
      assert_equal "yes", probe_value(output, "trashed_scope"), output
      assert_equal "no", probe_value(output, "active"), output
      assert_equal "no", probe_value(output, "kept_sql_method"), output
      assert_equal "yes", probe_value(output, "scopes_included"), output
      assert_equal "1", probe_value(output, "extension_count"), output
      assert_equal "yes", probe_value(output, "filter_registered"), output
      assert_equal "yes", probe_value(output, "after_reload_trashed_scope"), output
      assert_equal "no", probe_value(output, "after_reload_active"), output
      assert_equal "no", probe_value(output, "after_reload_kept_sql_method"), output
      assert_equal "yes", probe_value(output, "after_reload_scopes_included"), output
      assert_equal "1", probe_value(output, "after_reload_extension_count"), output
      assert_equal "yes", probe_value(output, "after_reload_filter_registered"), output
    end
  end

  def test_query_host_late_require_installs_scopes_before_reload
    [0, 1].each do |eager_load|
      output, status = run_query_host_probe(LATE_REQUIRE_QUERY_HOST_PROBE, eager_load: eager_load)

      assert_predicate status, :success?, "eager_load=#{eager_load}\n#{output}"
      assert_equal "no", probe_value(output, "pre_query_trashed"), output
      assert_equal "no", probe_value(output, "pre_query_filter"), output
      assert_equal "yes", probe_value(output, "late_require_trashed"), output
      assert_equal "no", probe_value(output, "late_require_active"), output
      assert_equal "no", probe_value(output, "late_require_kept_sql_method"), output
      assert_equal "yes", probe_value(output, "late_require_scopes_included"), output
      assert_equal "1", probe_value(output, "late_require_extension_count"), output
      assert_equal "yes", probe_value(output, "late_require_filter"), output
      assert_equal "no", probe_value(output, "engine"), output
      assert_equal "no", probe_value(output, "capability"), output
      assert_equal "no", probe_value(output, "flat_pack"), output
      assert_equal "no", probe_value(output, "engine_required"), output
      assert_equal "no", probe_value(output, "main_required"), output
    end
  end

  def test_query_source_registers_one_extend_model_hook
    source = File.read(File.expand_path("lib/recording_studio_trashable/query.rb", ROOT))
    main = File.read(File.expand_path("lib/recording_studio_trashable.rb", ROOT))

    assert_includes source, "def register_recording_scopes!"
    assert_includes source, "extend_model(:recording, &@recording_scope_extension)"
    assert_includes source, "include RecordingStudioTrashable::RecordingScopes"
    refute_includes source, "install_query_helpers!"
    refute_includes source, "to_prepare"
    assert_includes source, "if !defined?(RecordingStudioTrashable::Engine) && defined?(RecordingStudio::Recording)"
    assert_includes source, "RecordingStudio::Engine.apply_model_extensions!"
    assert_includes source, "RecordingStudioTrashable::RecordingFilter.register!"
    assert_includes source, "Rails.application.initialized?"
    refute_includes source, "to_prepare"
    assert_operator(
      main.index('require "recording_studio_trashable/engine"'),
      :<,
      main.index('require "recording_studio_trashable/query"')
    )
    assert_match(
      /RecordingStudio\.apply_capabilities!\n\s+RecordingStudio::Engine\.apply_model_extensions!/,
      main
    )
  end

  def test_full_gem_late_require_keeps_scopes_ahead_of_capability_methods
    [0, 1].each do |eager_load|
      output, status = run_query_host_probe(FULL_GEM_LATE_PROBE, eager_load: eager_load)

      assert_predicate status, :success?, "eager_load=#{eager_load}\n#{output}"
      assert_equal "no", probe_value(output, "pre_scopes_included"), output
      assert_scope_order(output, "late")
      assert_scope_order(output, "after_reload")
      assert_equal probe_value(output, "late_extension_count"),
                   probe_value(output, "after_reload_extension_count"),
                   output
      assert_equal "yes", probe_value(output, "extension_ids_stable"), output
    end
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

  private

  def run_probe(script, gemfile:, env: {})
    probe_env = {
      "BUNDLE_GEMFILE" => gemfile,
      "TRASHABLE_ROOT" => ROOT,
      "RUBYOPT" => ""
    }.merge(env)
    Open3.capture2e(probe_env, RbConfig.ruby, "-e", script, chdir: ROOT)
  end

  # Same root Gemfile as the gem suite (includes `pg` for this host). Pass through
  # DATABASE_URL when CI provides it so the host hits the migrated test DB.
  def run_query_host_probe(script, eager_load:)
    probe_env = {
      "QUERY_HOST_ROOT" => QUERY_HOST_ROOT,
      "EAGER_LOAD" => eager_load.to_s,
      "RAILS_ENV" => "test",
      "DB_HOST" => ENV.fetch("DB_HOST", "localhost"),
      "DB_PORT" => ENV.fetch("DB_PORT", "5432"),
      "DB_USER" => ENV.fetch("DB_USER", "postgres"),
      "DB_PASSWORD" => ENV.fetch("DB_PASSWORD", "postgres"),
      "DB_NAME" => ENV.fetch("DB_NAME", "app_test")
    }
    database_url = ENV.fetch("DATABASE_URL", nil)
    probe_env["DATABASE_URL"] = database_url if database_url.to_s.strip != ""

    run_probe(script, gemfile: ROOT_GEMFILE, env: probe_env)
  end

  def assert_scope_order(output, prefix)
    scopes_index = Integer(probe_value(output, "#{prefix}_scopes_index"))
    methods_index = Integer(probe_value(output, "#{prefix}_methods_index"))

    assert_operator scopes_index, :<, methods_index, output
    assert_equal "yes", probe_value(output, "#{prefix}_scopes_included"), output
    assert_equal "no", probe_value(output, "#{prefix}_active"), output
    assert_equal "yes", probe_value(output, "#{prefix}_trashed"), output
    assert_equal "yes", probe_value(output, "#{prefix}_filter"), output
  end

  def probe_value(output, key)
    line = output.lines.map(&:chomp).find { |entry| entry.start_with?("#{key}=") }
    refute_nil line, "missing probe key #{key.inspect} in:\n#{output}"
    line.delete_prefix("#{key}=")
  end
end
