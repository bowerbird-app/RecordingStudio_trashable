# frozen_string_literal: true

require_relative "mcp_copy/copy"

module RecordingStudioTrashable
  module McpCopy
    ACTIONS = %i[
      trashable_trash
      trashable_restore
      trashable_purge
      trashable_list_trash_bin
    ].freeze

    module_function

    def mcp_available?
      defined?(::RecordingStudioMcp) && ::RecordingStudioMcp.respond_to?(:register_tool)
    end

    def mcp
      ::RecordingStudioMcp
    end

    def register!
      return unless mcp_available?

      Api.trashable_types.each { |type| register_type_tools(type) }
    end

    def tool_name(type, action)
      return unless mcp_available? && mcp.respond_to?(:tool_name)
      return "#{mcp.tool_name(type, :list)}_trash_bin" if action.to_sym == :trashable_list_trash_bin

      mcp.tool_name(type, verb_for(action))
    end

    def register_type_tools(type)
      register_type_copy(type)
      ACTIONS.each { |action| register_action_tool(type, action) }
    end

    def register_type_copy(type)
      return unless mcp.respond_to?(:register_type)
      return if type_described?(type)

      mcp.register_type(type: type.to_s, description: Copy::TYPE)
    end

    def type_described?(type)
      return false unless mcp.respond_to?(:configuration)

      existing = mcp.configuration.type(type.to_s)
      existing.respond_to?(:description) && existing.description.to_s.strip != ""
    end

    def register_action_tool(type, action)
      mcp.register_tool(
        name: tool_name(type, action),
        type: type.to_s,
        action: action,
        title: title_for(type, action),
        description: description_for(type, action),
        input: Copy::INPUTS.fetch(action),
        output: Copy::OUTPUTS.fetch(action)
      )
    end

    def title_for(type, action)
      document = Api.openapi_for(type: type, action: action)
      title = document.is_a?(Hash) ? document[:title] : nil
      title.presence || Api::Catalog::ACTIONS.fetch(action).fetch(:title)
    end

    def description_for(_type, action)
      Copy::DESCRIPTIONS.fetch(action)
    end

    def verb_for(action)
      {
        trashable_trash: "trash",
        trashable_restore: "restore",
        trashable_purge: "purge"
      }.fetch(action.to_sym)
    end
    private_class_method :register_type_tools, :register_type_copy, :type_described?,
                         :register_action_tool, :title_for, :description_for,
                         :verb_for
  end
end
