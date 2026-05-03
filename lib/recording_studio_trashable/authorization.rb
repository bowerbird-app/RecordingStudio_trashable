# frozen_string_literal: true

module RecordingStudioTrashable
  module Authorization
    class << self
      def authorized?(action:, actor:, recording:, controller: nil)
        configuration = RecordingStudioTrashable.configuration
        role = configuration.role_for(action)
        payload = { action: action, actor: actor, recording: recording, controller: controller, role: role }
        custom_result = resolve_custom_authorization(configuration.authorization_resolver, **payload)
        return custom_result unless custom_result.nil?

        accessible_authorized?(configuration, actor: actor, recording: recording, role: role)
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

      def accessible_authorized?(configuration, actor:, recording:, role:)
        return configuration.allow_unconfigured_authorization unless configuration.use_recording_studio_accessible
        return configuration.allow_unconfigured_authorization unless accessible_authorizer_available?
        return configuration.allow_unconfigured_authorization if recording.nil? || actor.nil?

        if accessible_authorizer.respond_to?(:authorized?)
          accessible_authorizer.authorized?(actor: actor, recording: recording, role: role)
        else
          accessible_authorizer.allowed?(actor: actor, recording: recording, role: role)
        end
      end

      def accessible_authorizer_available?
        !accessible_authorizer.nil?
      end

      def accessible_authorizer
        if defined?(RecordingStudioAccessible) && RecordingStudioAccessible.respond_to?(:authorized?)
          RecordingStudioAccessible
        elsif defined?(::RecordingStudio::Services::AccessCheck) &&
              ::RecordingStudio::Services::AccessCheck.respond_to?(:allowed?)
          ::RecordingStudio::Services::AccessCheck
        end
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
        return unless controller.respond_to?(:current_user, true)

        controller.send(:current_user)
      end
    end
  end
end
