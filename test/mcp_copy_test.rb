# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class McpCopyTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  FORBIDDEN = %w[role permission Accessible RecordingStudioTrashable admin view edit].freeze

  NO_MCP_PROBE = <<~'RUBY'
    require "bundler/setup"
    require "simplecov"
    SimpleCov.command_name "mcp-absent"
    SimpleCov.start do
      enable_coverage :branch
      add_filter "/test/"
      add_filter "/config/"
      add_filter "/db/"
    end
    $LOAD_PATH.unshift File.expand_path("lib", ENV.fetch("TRASHABLE_ROOT"))
    require "recording_studio_trashable"

    puts "defined=#{defined?(::RecordingStudioMcp) ? 'yes' : 'no'}"
    puts "available=#{RecordingStudioTrashable::McpCopy.mcp_available? ? 'yes' : 'no'}"
    puts "register=#{RecordingStudioTrashable::McpCopy.register!.inspect}"
  RUBY

  REGISTRY_PROBE = <<~'RUBY'
    require "bundler/setup"
    require "simplecov"
    SimpleCov.command_name "mcp-registry"
    SimpleCov.start do
      enable_coverage :branch
      add_filter "/test/"
      add_filter "/config/"
      add_filter "/db/"
    end
    $LOAD_PATH.unshift File.expand_path("lib", ENV.fetch("TRASHABLE_ROOT"))
    require "active_record"
    require "recording_studio_trashable"
    require "recording_studio_mcp"

    def check(condition, message)
      abort(message) unless condition
    end

    configuration = RecordingStudio.configuration
    recordable_types = configuration.recordable_types.dup
    capabilities = configuration.instance_variable_get(:@capabilities).transform_values(&:dup)
    capability_options = configuration.instance_variable_get(:@capability_options).dup
    declarations = RecordingStudio::RecordableDeclarations.instance_variable_get(:@declaration_registry).dup
    registry = RecordingStudioMcp.configuration
    tools_before = registry.tools.dup
    types_before = registry.types.dup

    class ApplicationRecord < ActiveRecord::Base
      primary_abstract_class
    end

    RecordingStudio::RecordableDeclarations.install_active_record_macro!
    models = File.expand_path("test/dummy/app/models", ENV.fetch("TRASHABLE_ROOT"))
    %w[workspace project folder page admin_root].each { |name| load File.join(models, "#{name}.rb") }
    configuration.recordable_types = %w[Workspace Project Folder Page AdminRoot]

    copy = RecordingStudioTrashable::McpCopy::Copy
    check(RecordingStudioTrashable::Api.trashable_types == ["Page"], "trashable types")
    puts "trashable_types=Page"
    RecordingStudioTrashable::McpCopy.register!
    RecordingStudioTrashable::McpCopy.register!

    added = registry.tools.keys - tools_before.keys
    puts "added=#{added.sort.join(',')}"
    trash = registry.tool("trash_page")
    check(trash, "trash_page missing")
    puts "trash_type=#{trash.type}"
    puts "trash_kind=#{trash.target.kind}"
    puts "trash_action=#{trash.target.value}"
    puts "trash_title=#{trash.title}"
    puts "trash_description=#{trash.description}"
    puts "trash_input=#{trash.input.inspect}"
    puts "trash_output=#{trash.output}"
    restore = registry.tool("restore_page")
    puts "restore_title=#{restore.title}"
    puts "restore_description=#{restore.description}"
    puts "restore_recording_id=#{restore.input.key?('recording_id') ? 'yes' : 'no'}"
    purge = registry.tool("purge_page")
    puts "purge_title=#{purge.title}"
    puts "purge_description=#{purge.description}"
    puts "purge_recording_id=#{purge.input.key?('recording_id') ? 'yes' : 'no'}"
    list = registry.tool("list_pages_trash_bin")
    puts "singular_list=#{registry.tool('list_page_trash_bin') ? 'present' : 'absent'}"
    puts "list_title=#{list.title}"
    puts "list_description=#{list.description}"
    puts "list_q=#{list.input.key?('q') ? 'yes' : 'no'}"
    puts "type_description=#{registry.type('Page').description}"
    check(registry.type("Page").description == copy::TYPE, "type description")

    %w[Folder Project Workspace AdminRoot].each do |type|
      names = [
        RecordingStudioTrashable::McpCopy.tool_name(type, :trashable_trash),
        RecordingStudioTrashable::McpCopy.tool_name(type, :trashable_list_trash_bin)
      ]
      present = names.any? { |name| registry.tool(name) }
      puts "#{type.underscore}_named=#{present ? 'present' : 'absent'}"
    end
    %w[trashable_trash trashable_restore trashable_purge trashable_list_trash_bin].each do |name|
      puts "#{name}=#{registry.tool(name) ? 'present' : 'absent'}"
    end
    generic = registry.tool("capability_action")
    check(generic, "capability_action missing")
    puts "capability_action_type=#{generic.type}"
    puts "capability_action_added=#{added.include?('capability_action') ? 'yes' : 'no'}"

    RecordingStudioTrashable::Api.override_openapi(
      type: "Page",
      action: :trashable_trash,
      title: "Bin this page",
      description: "Moves this page, and everything under it, to the trash."
    )
    RecordingStudioTrashable::McpCopy.register!
    overridden = registry.tool("trash_page")
    puts "override_title=#{overridden.title}"
    puts "override_description=#{overridden.description}"
    puts "override_restore_description=#{registry.tool('restore_page').description}"
    RecordingStudioTrashable::Api::OpenapiOverrides.reset!

    registry.tools.replace(tools_before)
    registry.types.replace(types_before)
    registry.catalogs.invalidate!
    RecordingStudioMcp.register_type(type: "Page", description: "Host copy for pages.")
    RecordingStudioTrashable::McpCopy.register!
    RecordingStudioTrashable::McpCopy.register!
    puts "host_description=#{registry.type('Page').description}"
    puts "host_tool_description=#{registry.tool('trash_page').description}"

    registry.tools.replace(tools_before)
    registry.types.replace(types_before)
    registry.catalogs.invalidate!
    configuration.recordable_types = recordable_types
    configuration.instance_variable_set(:@capabilities, capabilities)
    configuration.instance_variable_set(:@capability_options, capability_options)
    RecordingStudio::RecordableDeclarations.replace_declarations!(declarations)
    puts "after_trash_page=#{registry.tool('trash_page') ? 'present' : 'absent'}"
    puts "after_list=#{registry.tool('list_pages_trash_bin') ? 'present' : 'absent'}"
    puts "after_page_type=#{registry.type('Page') ? 'present' : 'absent'}"
    puts "after_capability=#{RecordingStudio.capability_enabled?(:trashable, for: 'Page') ? 'yes' : 'no'}"
    puts "after_types_match=#{configuration.recordable_types == recordable_types ? 'yes' : 'no'}"
    class PressCenter < ApplicationRecord
      recording_studio_recordable label: "Press center", plural_label: "Press centres", root: false,
                                  allowed_parent_types: %w[Workspace]
    end
    puts "tool_name_trash=#{RecordingStudioTrashable::McpCopy.tool_name('Admin::Page', :trashable_trash)}"
    puts "tool_name_list=#{RecordingStudioTrashable::McpCopy.tool_name('Admin::Page', :trashable_list_trash_bin)}"
    puts "tool_name_press=#{RecordingStudioTrashable::McpCopy.tool_name('PressCenter', :trashable_list_trash_bin)}"
    puts "tool_name_purge=#{RecordingStudioTrashable::McpCopy.tool_name('Admin::Page', :trashable_purge)}"
    puts "registry_ok"
  RUBY

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    output, status = run_probe(NO_MCP_PROBE)

    assert status.success?, output
    assert_equal "no", probe_value(output, "defined")
    assert_equal "no", probe_value(output, "available")
    assert_equal "nil", probe_value(output, "register")
  end

  def test_named_tools_register_for_trashable_types_only
    output, status = run_probe(REGISTRY_PROBE)
    copy = RecordingStudioTrashable::McpCopy::Copy

    assert status.success?, output
    assert_includes output, "registry_ok"
    assert_equal "Page", probe_value(output, "trashable_types")
    assert_equal "list_pages_trash_bin,purge_page,restore_page,trash_page", probe_value(output, "added")
    assert_equal "Page", probe_value(output, "trash_type")
    assert_equal "action", probe_value(output, "trash_kind")
    assert_equal "trashable_trash", probe_value(output, "trash_action")
    assert_equal "Trash page", probe_value(output, "trash_title")
    assert_equal copy::TRASH, probe_value(output, "trash_description")
    assert_equal "{}", probe_value(output, "trash_input")
    assert_equal "The item after it moves to the trash.", probe_value(output, "trash_output")
    assert_equal "Restore page", probe_value(output, "restore_title")
    assert_equal copy::RESTORE, probe_value(output, "restore_description")
    assert_equal "yes", probe_value(output, "restore_recording_id")
    assert_equal "Purge page", probe_value(output, "purge_title")
    assert_equal copy::PURGE, probe_value(output, "purge_description")
    assert_equal "yes", probe_value(output, "purge_recording_id")
    assert_equal "List page trash bin", probe_value(output, "list_title")
    assert_equal copy::LIST, probe_value(output, "list_description")
    assert_equal "yes", probe_value(output, "list_q")
    assert_equal "absent", probe_value(output, "singular_list")
    assert_equal copy::TYPE, probe_value(output, "type_description")
    %w[folder project workspace admin_root].each do |snake|
      assert_equal "absent", probe_value(output, "#{snake}_named"), snake
    end
    %w[trashable_trash trashable_restore trashable_purge trashable_list_trash_bin].each do |name|
      assert_equal "absent", probe_value(output, name), name
    end
    assert_equal "", probe_value(output, "capability_action_type")
    assert_equal "no", probe_value(output, "capability_action_added")
    assert_equal "Bin this page", probe_value(output, "override_title")
    assert_equal copy::TRASH, probe_value(output, "override_description")
    assert_equal copy::RESTORE, probe_value(output, "override_restore_description")
    assert_equal "Host copy for pages.", probe_value(output, "host_description")
    assert_equal copy::TRASH, probe_value(output, "host_tool_description")
    assert_equal "absent", probe_value(output, "after_trash_page")
    assert_equal "absent", probe_value(output, "after_list")
    assert_equal "absent", probe_value(output, "after_page_type")
    assert_equal "no", probe_value(output, "after_capability")
    assert_equal "yes", probe_value(output, "after_types_match")
    assert_equal "trash_page", probe_value(output, "tool_name_trash")
    assert_equal "list_pages_trash_bin", probe_value(output, "tool_name_list")
    assert_equal "list_press_centres_trash_bin", probe_value(output, "tool_name_press")
    refute_includes probe_value(output, "tool_name_purge"), "::"
  end

  def test_tool_name_is_absent_without_mcp
    refute defined?(::RecordingStudioMcp)
    assert_nil RecordingStudioTrashable::McpCopy.tool_name("Page", :trashable_trash)
    assert_nil RecordingStudioTrashable::McpCopy.tool_name("Page", :trashable_list_trash_bin)
  end

  def test_copy_states_prerequisites_and_skips_access_roles
    copy = RecordingStudioTrashable::McpCopy::Copy

    assert_includes copy::PURGE, "must already be in the trash"
    assert_includes copy::PURGE, "cannot be undone"
    assert_includes copy::RESTORE, "Brings this item back"
    assert_includes copy::TRASH, "must still be active"
    assert_includes copy::LIST, "restore or purge"
    [copy::TYPE, *copy::DESCRIPTIONS.values, *copy::OUTPUTS.values].each do |text|
      FORBIDDEN.each { |phrase| refute_includes text.downcase, phrase.downcase }
    end
  end

  def test_gemspec_has_no_runtime_mcp_dependency_and_the_gemfile_sets_the_floor
    gemspec = File.read(File.expand_path("recording_studio_trashable.gemspec", ROOT))
    gemfile = File.read(File.expand_path("Gemfile", ROOT))
    query = File.read(File.expand_path("lib/recording_studio_trashable/query.rb", ROOT))
    api = File.read(File.expand_path("lib/recording_studio_trashable/api.rb", ROOT))
    registration = File.read(File.expand_path("lib/recording_studio_trashable/mcp_copy.rb", ROOT))

    refute_match(/add_dependency ["']recording_studio_mcp["']/, gemspec)
    assert_includes gemspec, "recording_studio_mcp cannot be a runtime dependency"
    assert_includes gemfile, 'gem "recording_studio_mcp", ">= 0.45", "< 0.46"'
    assert_includes gemfile, 'tag: "v0.45.2"'
    refute_includes query, "recording_studio_mcp"
    refute_includes query, "mcp_copy"
    assert_includes api, "McpCopy.register!"
    refute_includes registration, "Api.register!"
  end

  private

  def run_probe(script)
    Open3.capture2e(
      {
        "BUNDLE_GEMFILE" => File.expand_path("Gemfile", ROOT),
        "TRASHABLE_ROOT" => ROOT,
        "RUBYOPT" => ""
      },
      RbConfig.ruby,
      "-e",
      script,
      chdir: ROOT
    )
  end

  def probe_value(output, key)
    line = output.lines.find { |entry| entry.start_with?("#{key}=") }
    flunk("missing #{key} in #{output}") unless line

    line.split("=", 2).last.strip
  end
end
