# frozen_string_literal: true

require_relative "api/access"
require_relative "api/actions"
require_relative "api/catalog"

module RecordingStudioTrashable
  module Api
    module_function

    def register!
      return unless defined?(::RecordingStudioApi)
      return unless RecordingStudioApi.respond_to?(:register_capability_action)

      each_api { |api_name| register_api(api_name) }
    end

    def each_api
      if named_api_registration_supported?
        RecordingStudioApi.configuration.each_api { |definition| yield definition.name }
      else
        yield :public
      end
    end

    def named_api_registration_supported?
      RecordingStudioApi.respond_to?(:configuration) &&
        RecordingStudioApi.configuration.respond_to?(:each_api) &&
        accepts_api_keyword?(:capability_action) &&
        accepts_api_keyword?(:register_capability_action)
    end

    def accepts_api_keyword?(method_name)
      return false unless RecordingStudioApi.respond_to?(method_name)

      RecordingStudioApi.method(method_name).parameters.any? do |type, name|
        type == :keyrest || (name == :api && %i[key keyreq].include?(type))
      end
    end

    def register_api(api_name)
      Catalog::ACTIONS.each_key { |name| register_action(api_name, name) }
      register_resource_handlers(api_name)
    end

    def register_action(api_name, name)
      return if existing_action(api_name, name)

      RecordingStudioApi.register_capability_action(name, **action_options(api_name, name))
    end

    def existing_action(api_name, name)
      if named_api_registration_supported?
        RecordingStudioApi.capability_action(name, api: api_name)
      else
        RecordingStudioApi.capability_action(name)
      end
    end

    def action_options(api_name, name)
      spec = Catalog::ACTIONS.fetch(name)
      options = base_action_options(name, spec)
      options[:api] = api_name if named_api_registration_supported?
      options
    end

    def base_action_options(name, spec)
      {
        capability: :trashable,
        version: Catalog::ACTION_VERSION,
        http_verb: spec.fetch(:http_verb),
        required_role: spec.fetch(:required_role),
        handler: spec.fetch(:handler),
        serializer: method(:serialize),
        input_contract: Catalog.contract_for(name),
        openapi: Catalog.openapi_for(name)
      }
    end

    def serialize(result)
      result
    end

    def register_resource_handlers(api_name)
      return unless RecordingStudioApi.respond_to?(:register_resource_handler)
      return unless RecordingStudio.respond_to?(:capability_enabled?)

      trashable_types.each { |type| register_type_handlers(api_name, type) }
    end

    def register_type_handlers(api_name, recordable_type)
      Catalog::ACTIONS.each_key do |name|
        next if RecordingStudioApi.resource_handler(recordable_type, name, api: api_name)

        RecordingStudioApi.register_resource_handler(
          recordable_type, name, api: api_name, handler: Catalog::ACTIONS.fetch(name).fetch(:handler)
        )
      end
    end

    def trashable_types
      Array(RecordingStudio.configuration.recordable_types).select do |type|
        RecordingStudio.capability_enabled?(:trashable, for: type)
      end
    end
  end
end
