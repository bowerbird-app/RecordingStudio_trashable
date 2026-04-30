# frozen_string_literal: true

module RecordingStudioTrashable
  module Authorization
    class << self
      def authorized?(action:, actor:, recording:, controller: nil)
        configuration = RecordingStudioTrashable.configuration
        custom_result = resolve_custom_authorization(
          configuration.authorization_resolver,
          action: action,
          actor: actor,
          recording: recording,
          controller: controller,
          role: configuration.role_for(action)
        )
        return custom_result unless custom_result.nil?

        return true unless configuration.accessible_integration_enabled
        return true unless defined?(RecordingStudioAccessible) && RecordingStudioAccessible.respond_to?(:authorized?)
        return false if recording.nil? || actor.nil?

        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: configuration.role_for(action)
        )
      end

      def mounted_page_authorized?(action:, actor:, recording:, controller: nil)
        resolver = RecordingStudioTrashable.configuration.mounted_page_authorizer
        return authorized?(action: action, actor: actor, recording: recording, controller: controller) unless resolver

        !!resolver.call(action: action, actor: actor, recording: recording, controller: controller)
      end

      def current_actor(controller: nil)
        resolve_context(RecordingStudioTrashable.configuration.current_actor_resolver, controller) ||
          current_attribute(:actor) ||
          controller_current_user(controller)
      end

      def current_impersonator(controller: nil)
        resolve_context(RecordingStudioTrashable.configuration.current_impersonator_resolver, controller) ||
          current_attribute(:impersonator)
      end

      private

      def resolve_custom_authorization(resolver, **payload)
        return nil unless resolver

        !!resolver.call(**payload)
      end

      def resolve_context(resolver, controller)
        return unless resolver

        resolver.call(controller: controller)
      end

      def current_attribute(name)
        return unless defined?(Current) && Current.respond_to?(name)

        Current.public_send(name)
      end

      def controller_current_user(controller)
        return unless controller&.respond_to?(:current_user, true)

        controller.send(:current_user)
      end
    end
  end
end
