# frozen_string_literal: true

require "recording_studio"
require "flat_pack"
require "recording_studio_trashable/version"
require "recording_studio_trashable/hooks"
require "recording_studio_trashable/configuration"
require "recording_studio_trashable/authorization"
require "recording_studio_trashable/retention_policy"
require "recording_studio_trashable/retention_purger"
require "recording_studio_trashable/engine"
require "recording_studio/trashable/capabilities/trashable"

if defined?(RecordingStudio::Recording)
  RecordingStudio.apply_capabilities!
  unless RecordingStudio::Recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes)
    RecordingStudio::Recording.include(RecordingStudioTrashable::RecordingScopes)
  end
end

module RecordingStudioTrashable
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def authorized?(action:, actor:, recording:, controller: nil)
      Authorization.authorized?(action: action, actor: actor, recording: recording, controller: controller)
    end

    def mounted_page_authorized?(action:, actor:, recording:, controller: nil)
      Authorization.mounted_page_authorized?(action: action, actor: actor, recording: recording, controller: controller)
    end

    def current_actor(controller: nil)
      Authorization.current_actor(controller: controller)
    end

    def current_impersonator(controller: nil)
      Authorization.current_impersonator(controller: controller)
    end

    def retention_setting_for(recording)
      RetentionSetting.find_or_initialize_by(recording: recording)
    end

    def capability_options_for(recording_or_type)
      type_name =
        case recording_or_type
        when nil
          nil
        when String
          recording_or_type
        when Symbol
          recording_or_type.to_s
        when Class
          recording_or_type.name
        else
          recording_or_type.respond_to?(:recordable_type) ? recording_or_type.recordable_type : recording_or_type.class.name
        end

      return {} if type_name.blank?

      RecordingStudio.capability_options(:trashable, for_type: type_name).to_h.symbolize_keys
    rescue NoMethodError
      {}
    end

    def include_children_for(recording:, include_children: nil)
      return include_children == true unless include_children.nil?

      capability_options = capability_options_for(recording)
      return capability_options[:include_children] == true if capability_options.key?(:include_children)

      return configuration.default_include_children == true unless configuration.default_include_children.nil?

      return RecordingStudio.configuration.include_children == true if RecordingStudio.respond_to?(:configuration)

      false
    end

    def purge_due_recordings(scope_recording:, actor: nil, impersonator: nil, as_of: Time.current, metadata: {})
      RetentionPurger.new(
        scope_recording: scope_recording,
        actor: actor,
        impersonator: impersonator,
        as_of: as_of,
        metadata: metadata
      ).purge!
    end
  end
end
