# frozen_string_literal: true

require "recording_studio"
require "flat_pack"
require "pagy"
require "pagy/backend"
require "pagy/frontend"
require "recording_studio_trashable/version"
require "recording_studio_trashable/hooks"
require "recording_studio_trashable/configuration"
require "recording_studio_trashable/authorization"
require "recording_studio_trashable/retention_policy"
require "recording_studio_trashable/retention_purger"
require "recording_studio_trashable/retention_purge_job"
require "recording_studio_trashable/engine"
require "recording_studio/trashable/capabilities/trashable"

if defined?(RecordingStudio::Recording)
  RecordingStudio.apply_capabilities!
  unless RecordingStudio::Recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes)
    RecordingStudio::Recording.include(RecordingStudioTrashable::RecordingScopes)
  end
end

module RecordingStudioTrashable
  SweepResult = Struct.new(:purged_recordings, :skipped_recordings, :scope_recordings, keyword_init: true)

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def allow_user_retention_settings?
      configuration.allow_user_retention_settings == true
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
      type_name = capability_type_name(recording_or_type)

      return {} if type_name.blank?

      RecordingStudio.capability_options(:trashable, for_type: type_name).to_h.symbolize_keys
    rescue NoMethodError
      {}
    end

    def include_children?(recording:, include_children: nil)
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

    def purge_due_recordings_for_all_scopes(scope_recordings: root_scope_recordings, **purge_options)
      purge_options = default_purge_options.merge(purge_options)

      Array(scope_recordings).compact.each_with_object(build_sweep_result) do |scope_recording, result|
        append_scope_purge_result(
          result: result,
          scope_recording: scope_recording,
          purge_options: purge_options
        )
      end
    end

    def root_scope_recordings
      return [] unless defined?(RecordingStudio::Recording)

      RecordingStudio::Recording
        .recording_studio_trashable_including_trashed
        .where(parent_recording_id: nil)
        .reorder(created_at: :asc)
        .to_a
    rescue NoMethodError
      []
    end

    def retention_purge_actor
      resolve_retention_purge_context(configuration.retention_purge_actor_resolver)
    end

    def retention_purge_impersonator
      resolve_retention_purge_context(configuration.retention_purge_impersonator_resolver)
    end

    private

    def resolve_retention_purge_context(resolver)
      return unless resolver

      resolver.call
    end

    def build_sweep_result
      SweepResult.new(purged_recordings: [], skipped_recordings: [], scope_recordings: [])
    end

    def default_purge_options
      {
        actor: retention_purge_actor,
        impersonator: retention_purge_impersonator,
        as_of: Time.current,
        metadata: {}
      }
    end

    def append_scope_purge_result(result:, scope_recording:, purge_options:)
      scope_result = purge_due_recordings(scope_recording: scope_recording, **purge_options)

      result.scope_recordings << scope_recording
      result.purged_recordings.concat(scope_result.purged_recordings)
      result.skipped_recordings.concat(scope_result.skipped_recordings)
    end

    def capability_type_name(recording_or_type)
      return if recording_or_type.nil?
      return recording_or_type if recording_or_type.is_a?(String)
      return recording_or_type.to_s if recording_or_type.is_a?(Symbol)
      return recording_or_type.name if recording_or_type.is_a?(Class)

      capability_type_name_from_record(recording_or_type)
    end

    def capability_type_name_from_record(recording_or_type)
      return recording_or_type.recordable_type if recording_or_type.respond_to?(:recordable_type)

      recording_or_type.class.name
    end
  end
end
