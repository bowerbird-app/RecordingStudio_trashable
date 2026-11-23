# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  FORBIDDEN = %w[role permission Accessible RecordingStudioTrashable admin view edit].freeze
  GENERIC_NAMES = %w[
    capability_action trashable_trash trashable_restore trashable_purge trashable_list_trash_bin
  ].freeze

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    refute defined?(::RecordingStudioMcp)

    RecordingStudioTrashable::McpCopy.stub(:mcp_available?, false) do
      assert_nil RecordingStudioTrashable::McpCopy.register!
    end
    assert_nil RecordingStudioTrashable::McpCopy.register!
  end

  def test_named_tools_register_for_trashable_types_only
    fake = RecordingMcp.new

    with_types("Page") do
      RecordingStudioTrashable::McpCopy.stub(:mcp_available?, true) do
        RecordingStudioTrashable::McpCopy.stub(:mcp, fake) do
          RecordingStudioTrashable::McpCopy.register!
        end
      end
    end

    assert_equal %w[trash_page restore_page purge_page list_page_trash_bin], fake.tools.keys
    trash = fake.tools.fetch("trash_page")
    assert_equal :trashable_trash, trash.fetch(:action)
    assert_equal "Page", trash.fetch(:type)
    assert_equal RecordingStudioTrashable::McpCopy::Copy::TRASH, trash.fetch(:description)
    assert_equal({}, trash.fetch(:input))
    assert_equal "The item after it moves to the trash.", trash.fetch(:output)
    assert fake.tools.fetch("purge_page").fetch(:input).key?("recording_id")
    assert fake.tools.fetch("list_page_trash_bin").fetch(:input).key?("q")
    GENERIC_NAMES.each { |name| refute fake.tools.key?(name), name }
    refute fake.tools.key?("trash_project")
    refute fake.tools.key?("list_project_trash_bin")
  end

  def test_openapi_override_replaces_title_and_description
    RecordingStudioTrashable::Api.override_openapi(
      type: "Page",
      action: :trashable_trash,
      title: "Bin this page",
      description: "Moves this page, and everything under it, to the trash."
    )
    fake = RecordingMcp.new

    with_types("Page") do
      RecordingStudioTrashable::McpCopy.stub(:mcp_available?, true) do
        RecordingStudioTrashable::McpCopy.stub(:mcp, fake) do
          RecordingStudioTrashable::McpCopy.register!
        end
      end
    end

    trash = fake.tools.fetch("trash_page")
    assert_equal "Bin this page", trash.fetch(:title)
    assert_equal "Moves this page, and everything under it, to the trash.", trash.fetch(:description)
    assert_equal RecordingStudioTrashable::McpCopy::Copy::RESTORE, fake.tools.fetch("restore_page").fetch(:description)
  ensure
    RecordingStudioTrashable::Api::OpenapiOverrides.reset!
  end

  def test_existing_type_description_is_left_in_place
    fake = RecordingMcp.new
    fake.descriptions["Page"] = "Host copy for pages."

    with_types("Page") do
      RecordingStudioTrashable::McpCopy.stub(:mcp_available?, true) do
        RecordingStudioTrashable::McpCopy.stub(:mcp, fake) do
          RecordingStudioTrashable::McpCopy.register!
          RecordingStudioTrashable::McpCopy.register!
        end
      end
    end

    assert_empty fake.types
    assert_equal "Host copy for pages.", fake.descriptions.fetch("Page")
    assert_equal %w[trash_page restore_page purge_page list_page_trash_bin], fake.tools.keys
  end

  def test_tool_names_drop_namespaces_and_follow_mcp_public_names
    assert_equal "trash_page", RecordingStudioTrashable::McpCopy.tool_name("Admin::Page", :trashable_trash)
    assert_equal "list_page_trash_bin",
                 RecordingStudioTrashable::McpCopy.tool_name("Admin::Page", :trashable_list_trash_bin)
    refute_includes RecordingStudioTrashable::McpCopy.tool_name("Admin::Page", :trashable_purge), "::"

    fake = RecordingMcp.new
    fake.public_name = "show_kit"
    RecordingStudioTrashable::McpCopy.stub(:mcp_available?, true) do
      RecordingStudioTrashable::McpCopy.stub(:mcp, fake) do
        assert_equal "restore_kit", RecordingStudioTrashable::McpCopy.tool_name("Page", :trashable_restore)
        assert_equal "list_kit_trash_bin",
                     RecordingStudioTrashable::McpCopy.tool_name("Page", :trashable_list_trash_bin)
      end
    end
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

  def with_types(*types, &)
    RecordingStudioTrashable::Api.stub(:trashable_types, types, &)
  end

  class RecordingMcp
    attr_reader :tools, :types, :descriptions
    attr_accessor :public_name

    def initialize
      @tools = {}
      @types = []
      @descriptions = {}
      @public_name = nil
    end

    def configuration
      self
    end

    def type(name)
      description = descriptions[name.to_s]
      return if description.nil?

      Struct.new(:description).new(description)
    end

    def register_type(type:, description:)
      types << { type: type, description: description }
      descriptions[type] = description
    end

    def register_tool(**registration)
      tools[registration.fetch(:name)] = registration
    end

    def tool_name(_type, action)
      return public_name if action.to_sym == :show

      "unused"
    end
  end
end
