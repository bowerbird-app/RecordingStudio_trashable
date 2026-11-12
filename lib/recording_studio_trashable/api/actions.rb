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
        def self.call(context)
          Errors.wrap { new(context).call }
        end

        def initialize(context)
          @context = context
        end

        def call
          recording = Lookup.recording(context)
          context.access_grant.authorize!(recording: recording, role: :edit, include_trashed: true)
          Payload.wrap(context, { records: serialized_records(recording) })
        end

        private

        attr_reader :context

        def serialized_records(recording)
          relation = RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(
            recording,
            query: context.params[:q]
          )
          relation = relation.limit(context.params[:limit]) if context.params[:limit]
          relation.map { |trashed| Payload.serialize(context, trashed) }
        end
      end
    end
  end
end
