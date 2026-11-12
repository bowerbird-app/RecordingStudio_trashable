# frozen_string_literal: true

require_relative "api/access"
require_relative "api/actions"
require_relative "api/catalog"

module RecordingStudioTrashable
  module Api
    module_function

    def register!
      return unless defined?(::RecordingStudioApi)

      RecordingStudioApi.configuration.each_api { |api| register_api(api.name) }
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
        capability: :trashable,
        version: Catalog::ACTION_VERSION,
        serializer: nil,
        input_contract: Catalog.contract_for(name),
        openapi: Catalog.openapi_for(name),
        api: api_name
      )
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

        RecordingStudioApi.register_resource_handler(recordable_type, name, api: api_name, handler:)
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
  end
end
