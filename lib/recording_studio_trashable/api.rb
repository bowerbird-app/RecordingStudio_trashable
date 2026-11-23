# frozen_string_literal: true

require_relative "api/access"
require_relative "api/actions"
require_relative "api/catalog"
require_relative "api/openapi_overrides"
require_relative "mcp_copy"

module RecordingStudioTrashable
  module Api
    module_function

    def register!
      return unless defined?(::RecordingStudioApi)

      RecordingStudioApi.configuration.each_api { |api| register_api(api.name) }
      McpCopy.register!
    end

    def register_api(api_name)
      Catalog::ACTIONS.each_key { |name| register_action(api_name, name) }
      register_resource_handlers(api_name)
    end

    def register_action(api_name, name)
      handler = Catalog::ACTIONS.fetch(name).fetch(:handler)
      existing = RecordingStudioApi.capability_action(name, api: api_name)
      if existing
        raise_mismatched_registration!(name, api_name, existing.handler, handler)
        return
      end

      RecordingStudioApi.register_capability_action(name, **action_options(api_name, name))
    end

    def action_options(api_name, name)
      spec = Catalog::ACTIONS.fetch(name)
      spec.slice(:http_verb, :required_role, :handler).merge(
        **scope_options(name),
        capability: :trashable,
        version: Catalog::ACTION_VERSION,
        serializer: nil,
        input_contract: Catalog.contract_for(name),
        openapi: Catalog.openapi_for(name), openapi_for: ->(type:, action:) { openapi_for(type:, action:) },
        api: api_name
      )
    end

    def override_openapi(type:, action:, title:, description:)
      OpenapiOverrides.store(type: type, action: action, title: title, description: description)
    end

    def openapi_for(type:, action:)
      name = OpenapiOverrides.normalized_action!(action)
      document = Catalog.openapi_for(name).deep_dup
      overlay = OpenapiOverrides.fetch(type, name)
      return document.merge(overlay) if overlay

      phrase = type_phrase(type)
      return if phrase.nil?

      document.merge(title: Catalog.type_title(name, phrase))
    end

    # API 0.26+ hides trashed rows unless the action opts in. Trash stays on kept rows.
    def scope_options(name)
      case name
      when :trashable_restore
        { include_trashed: true, trashed_semantics: :restore }
      when :trashable_purge
        { include_trashed: true, trashed_semantics: :destroy }
      when :trashable_list_trash_bin
        { include_trashed: true }
      else
        {}
      end
    end

    def register_resource_handlers(api_name)
      trashable_types.each { |type| register_type_handlers(api_name, type) }
    end

    def register_type_handlers(api_name, recordable_type)
      Catalog::ACTIONS.each do |name, spec|
        handler = spec.fetch(:handler)
        existing = RecordingStudioApi.resource_handler(recordable_type, name, api: api_name)
        raise_mismatched_registration!(name, api_name, existing, handler, recordable_type:) if existing
        next if existing

        RecordingStudioApi.register_resource_handler(
          recordable_type, name, api: api_name, handler:, **scope_options(name)
        )
      end
    end

    def raise_mismatched_registration!(name, api_name, existing, handler, recordable_type: nil)
      return if identical_handler?(existing, handler)

      scope = recordable_type ? "#{recordable_type} #{name}" : name
      raise RecordingStudioApi::ConfigurationError,
            "Recording Studio API #{scope} on #{api_name} is already registered with a different handler"
    end

    def identical_handler?(existing, handler)
      return true if existing == handler

      existing_name = existing.respond_to?(:name) ? existing.name : nil
      handler_name = handler.respond_to?(:name) ? handler.name : nil
      existing_name.present? && existing_name == handler_name
    end

    def trashable_types
      Array(RecordingStudio.configuration.recordable_types).select do |type|
        RecordingStudio.capability_enabled?(:trashable, for: type)
      end
    end

    def type_phrase(type)
      type_name = type.to_s
      return if type_name.blank?
      return unless declared_recordable?(type_name)

      phrase = RecordingStudio.recordable_type_label(type_name).to_s.squish.downcase
      phrase.presence
    end

    def declared_recordable?(type_name)
      Array(RecordingStudio.configuration.recordable_types).map(&:to_s).include?(type_name)
    end
    private_class_method :type_phrase, :declared_recordable?
  end
end
