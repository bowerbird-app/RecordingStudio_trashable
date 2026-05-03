# frozen_string_literal: true

module RecordingStudioTrashable
  class PurgeTargetsNotTrashedError < ArgumentError; end
end

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

module RecordingStudioTrashable
  SweepResult = Struct.new(
    :purged_recordings,
    :skipped_recordings,
    :would_purge_recordings,
    :scope_recordings,
    keyword_init: true
  )

  class << self
    def install_recording_capabilities!
      return unless defined?(RecordingStudio::Recording)

      RecordingStudio.apply_capabilities!
      return if RecordingStudio::Recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes)

      RecordingStudio::Recording.include(RecordingStudioTrashable::RecordingScopes)
    end

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

    # rubocop:disable Metrics/ParameterLists
    def purge_due_recordings(
      scope_recording:,
      actor: nil,
      impersonator: nil,
      as_of: Time.current,
      metadata: {},
      dry_run: false
    )
      RetentionPurger.new(
        scope_recording: scope_recording,
        actor: actor,
        impersonator: impersonator,
        as_of: as_of,
        metadata: metadata,
        dry_run: dry_run
      ).purge!
    end
    # rubocop:enable Metrics/ParameterLists

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

    def purge_summary_message(result, dry_run: false)
      purge_count = dry_run ? result.would_purge_recordings.size : result.purged_recordings.size
      skipped_count = result.skipped_recordings.size
      message = base_purge_summary_message(purge_count, dry_run: dry_run)

      return message if skipped_count.zero?

      "#{message} Skipped #{count_label(skipped_count, 'recording')}."
    end

    def base_purge_summary_message(purge_count, dry_run: false)
      return dry_run_purge_summary_message(purge_count) if dry_run

      return "Purged #{count_label(purge_count, 'recording')}." if purge_count.positive?

      "No recordings were purged."
    end

    def dry_run_purge_summary_message(purge_count)
      return "Dry run: no recordings would be purged." unless purge_count.positive?

      "Dry run: #{count_label(purge_count, 'recording')} would be purged."
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
      SweepResult.new(purged_recordings: [], skipped_recordings: [], would_purge_recordings: [], scope_recordings: [])
    end

    def default_purge_options
      {
        actor: retention_purge_actor,
        impersonator: retention_purge_impersonator,
        as_of: Time.current,
        metadata: {},
        dry_run: false
      }
    end

    def append_scope_purge_result(result:, scope_recording:, purge_options:)
      scope_result = purge_due_recordings(scope_recording: scope_recording, **purge_options)

      result.scope_recordings << scope_recording
      result.purged_recordings.concat(scope_result.purged_recordings)
      result.skipped_recordings.concat(scope_result.skipped_recordings)
      result.would_purge_recordings.concat(scope_result.would_purge_recordings)
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

    def count_label(count, noun)
      "#{count} #{noun.pluralize(count)}"
    end
  end
end

RecordingStudioTrashable.install_recording_capabilities!
