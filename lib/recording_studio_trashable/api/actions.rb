# frozen_string_literal: true

require_relative "errors"

module RecordingStudioTrashable
  module Api
    module Actions
      module Lookup
        module_function

        def recording(context)
          recording_id = context.id.presence || context.recording&.id
          recording = context.access_grant.accessible_recordings(include_trashed: true).find_by(id: recording_id)
          raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if recording.nil?

          recording
        end

        def action_recording(context, action)
          scope = recording(context)
          requested_id = requested_recording_id(context)
          return scope if requested_id.nil?

          target = trash_root_in_subtree(scope, requested_id)
          raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if target.nil?

          authorize_target!(context, target, action)
          target
        end

        def requested_recording_id(context)
          text = context.params[:recording_id].to_s.strip
          text unless text.empty?
        end

        def trash_root_in_subtree(scope, recording_id)
          RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(scope).find_by(id: recording_id)
        end

        def authorize_target!(context, recording, action)
          return if RecordingStudioTrashable.authorized?(action: action, actor: context.actor, recording: recording)

          raise RecordingStudioApi::AuthorizationError, RecordingStudioTrashable::Copy.t(
            "errors.not_authorized",
            action: RecordingStudioTrashable::Copy.action_name(action),
            type: recording.recordable_type
          )
        end
      end

      module Payload
        module_function

        def wrap(context, body)
          return { json: body } if context.recordable_type

          body
        end

        def recording(context, recording)
          wrap(context, serialize(context, recording))
        end

        def serialize(context, recording, relationship_context: nil, reuse_context: false)
          context_for_recording = reuse_context ? relationship_context : relationship_context_for(context, [recording])
          RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
            recording,
            **serializer_arguments(context, context_for_recording)
          )
        end

        def trash_bin_records(context, recordings)
          relationship_context = relationship_context_for(context, recordings)
          recordings.map do |recording|
            trash_bin_record(context, recording, relationship_context: relationship_context)
          end
        end

        def trash_bin_record(context, recording, relationship_context:)
          serialize(context, recording, relationship_context: relationship_context, reuse_context: true).merge(
            "label" => RecordingStudioTrashable::RecordingLabel.for(recording),
            "recordable_type" => recording.recordable_type
          )
        end

        def serializer_arguments(context, relationship_context)
          arguments = { api: api_key_for(context) }
          return arguments if relationship_context.nil?

          arguments.merge(version: api_version_for(context), context: relationship_context)
        end

        def relationship_context_for(context, recordings)
          grant = access_grant_for(context)
          return if grant.nil?

          RecordingStudioApi::RelationshipContext.for(
            recordings: recordings, include_values: include_values_for(context),
            scoped_recordings: grant.accessible_recordings, api_key: api_key_for(context),
            api_version: api_version_for(context), access_grant: grant, params: request_params(context)
          )
        end

        def access_grant_for(context)
          return unless defined?(RecordingStudioApi::RelationshipContext)
          return unless context.respond_to?(:access_grant)

          grant = context.access_grant
          grant if grant.respond_to?(:accessible_recordings)
        end

        def api_key_for(context)
          return context.api_key if context.respond_to?(:api_key)

          :public
        end

        def api_version_for(context)
          explicit = explicit_api_version(context)
          return explicit if explicit.present?

          default_api_version(context)
        end

        def explicit_api_version(context)
          version = context.api_version if context.respond_to?(:api_version)
          return version if version.present?

          param_value(request_params(context), :api_version)
        end

        def default_api_version(context)
          return unless RecordingStudioApi.respond_to?(:default_api_version)

          RecordingStudioApi.default_api_version(api: api_key_for(context))
        rescue StandardError
          nil
        end

        def include_values_for(context)
          param_value(request_params(context), :include)
        end

        def request_params(context)
          return {} unless context.respond_to?(:params)

          context.params || {}
        end

        def param_value(params, name)
          return unless params.respond_to?(:key?)
          return params[name] if params.key?(name)

          string_name = name.to_s
          params[string_name] if params.key?(string_name)
        end
      end

      class Trash
        def self.call(context)
          Errors.wrap { new(context).call }
        end

        def initialize(context)
          @context = context
        end

        def call
          recording = Lookup.recording(context)
          raise RecordingStudioApi::InvalidActionInputError, already_trashed_message if already_trashed?(recording)

          recording.recording_studio_trashable_trash!(actor: context.actor, metadata: metadata("trash"))
          Payload.recording(context, recording.reload)
        end

        private

        attr_reader :context

        def already_trashed?(recording)
          recording.recording_studio_trashable_trashed?
        end

        def already_trashed_message
          RecordingStudioTrashable::Copy.t("errors.already_trashed")
        end

        def metadata(action)
          { source: "recording_studio_api", api_action: action }
        end
      end

      class Restore
        def self.call(context)
          Errors.wrap { new(context).call }
        end

        def initialize(context)
          @context = context
        end

        def call
          recording = Lookup.action_recording(context, :restore)
          raise RecordingStudioApi::InvalidActionInputError, not_trashed_message unless trashed?(recording)

          recording.recording_studio_trashable_restore!(actor: context.actor, metadata: metadata)
          Payload.recording(context, recording.reload)
        end

        private

        attr_reader :context

        def trashed?(recording)
          recording.recording_studio_trashable_trashed?
        end

        def not_trashed_message
          RecordingStudioTrashable::Copy.t("errors.not_trashed")
        end

        def metadata
          { source: "recording_studio_api", api_action: "restore" }
        end
      end

      class Purge
        def self.call(context)
          Errors.wrap { new(context).call }
        end

        def initialize(context)
          @context = context
        end

        def call
          recording = Lookup.action_recording(context, :purge)
          recording.recording_studio_trashable_purge!(actor: context.actor, metadata: metadata)
          Payload.wrap(context, { id: recording.id, purged: true })
        end

        private

        attr_reader :context

        def metadata
          { source: "recording_studio_api", api_action: "purge" }
        end
      end

      class ListTrashBin
        PAGE_SIZE = 25
        MAX_PAGE_SIZE = 100

        def self.call(context)
          Errors.wrap { new(context).call }
        end

        def initialize(context)
          @context = context
        end

        def call
          recording = Lookup.recording(context)
          authorize_trash_bin!(recording)
          Payload.wrap(context, { records: serialized_records(recording) })
        end

        private

        attr_reader :context

        def authorize_trash_bin!(recording)
          return if RecordingStudioTrashable.authorized?(
            action: :trash_bin, actor: context.actor, recording: recording
          )

          raise RecordingStudioApi::AuthorizationError, RecordingStudioTrashable::Copy.t(
            "errors.not_authorized",
            action: RecordingStudioTrashable::Copy.action_name(:trash_bin),
            type: recording.recordable_type
          )
        end

        def serialized_records(recording)
          Payload.trash_bin_records(context, trash_bin_page(recording))
        end

        def trash_bin_page(recording)
          page = page_param
          per_page = per_page_param
          RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(
            recording,
            query: context.params[:q].to_s.strip
          ).reorder(trashed_at: :desc, id: :desc).offset((page - 1) * per_page).limit(per_page).to_a
        end

        def page_param
          positive_integer(context.params[:page], default: 1)
        end

        def per_page_param
          [positive_integer(context.params[:per_page], default: PAGE_SIZE), MAX_PAGE_SIZE].min
        end

        def positive_integer(value, default:)
          return default if value.nil? || (value.is_a?(String) && value.strip.empty?)

          parsed = Integer(value)
          raise ArgumentError if parsed < 1

          parsed
        rescue ArgumentError, TypeError
          raise RecordingStudioApi::InvalidActionInputError,
                Catalog::UNPROCESSABLE.fetch(:trashable_list_trash_bin)
        end
      end
    end
  end
end
