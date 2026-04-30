# frozen_string_literal: true

require "recording_studio"
require "flat_pack"
require "recording_studio_trashable/version"
require "recording_studio_trashable/hooks"
require "recording_studio_trashable/configuration"
require "recording_studio_trashable/authorization"
require "recording_studio_trashable/retention_policy"
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
  end
end
