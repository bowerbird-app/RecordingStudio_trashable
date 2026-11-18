# frozen_string_literal: true

module RecordingStudioTrashable
  module Api
    module OpenapiOverrides
      module_function

      def store(type:, action:, title:, description:)
        type_name = type.to_s
        raise ArgumentError, "type is required" if type_name.blank?
        raise ArgumentError, "title is required" if title.nil?
        raise ArgumentError, "description is required" if description.nil?

        name = normalized_action!(action)
        entries[type_name] ||= {}
        entries[type_name][name] = { title: title, description: description }.freeze
        nil
      end

      def fetch(type, action)
        return if type.nil?

        entries.dig(type.to_s, action.to_sym)
      end

      def reset!
        @entries = {}
      end

      def entries
        @entries ||= {}
      end

      def normalized_action!(action)
        name = action.to_sym
        return name if Catalog::ACTIONS.key?(name)

        raise ArgumentError, "Unknown trashable action #{action.inspect}"
      end
    end
  end
end
