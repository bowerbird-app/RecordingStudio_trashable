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

        def serialize(context, recording)
          RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
            recording,
            api: context.api_key
          )
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
          context.access_grant.authorize!(recording: recording, role: :edit, include_trashed: true)
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
          recording = Lookup.recording(context)
          context.access_grant.authorize!(recording: recording, role: :edit, include_trashed: true)
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
          recording = Lookup.recording(context)
          context.access_grant.authorize!(recording: recording, role: :admin, include_trashed: true)
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

        def self.call(context)
          Errors.wrap { new(context).call }
        end

        def initialize(context)
          @context = context
        end

        def call
          recording = Lookup.recording(context)
          context.access_grant.authorize!(recording: recording, role: :edit, include_trashed: true)
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
          page = page_param
          per_page = per_page_param
          relation = RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(
            recording,
            query: context.params[:q].to_s.strip
          ).reorder(trashed_at: :desc, id: :desc)
          relation.offset((page - 1) * per_page).limit(per_page).map do |trashed|
            Payload.serialize(context, trashed)
          end
        end

        def page_param
          positive_integer(context.params[:page], default: 1)
        end

        def per_page_param
          positive_integer(context.params[:per_page], default: PAGE_SIZE)
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
