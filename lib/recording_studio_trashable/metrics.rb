# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioTrashable
  module Metrics
    RESOURCE = :trash
    API = :operations
    EXPOSE = { api: [API] }.freeze
    CURRENT_TRASH_DESCRIPTION =
      "Current trash only. Purged items vanish and are not counted. " \
      "trashed_over_time uses trashed_at of still-existing items, not a purge event log."

    module_function

    def register!
      RecordingStudioMetrics.register(
        RESOURCE,
        model: RecordingStudio::Recording,
        blast_radius: :site,
        scope: ->(relation) { relation.unscope(where: :trashed_at).where.not(trashed_at: nil) },
        api_authorize: ->(context) { RecordingStudioTrashable::Api::Access.can_view?(context) }
      ) do
        RecordingStudioTrashable::Metrics.define_trash(self)
      end
    end

    def define_trash(dsl)
      define_in_trash(dsl)
      define_in_trash_by_type(dsl)
      define_trashed_over_time(dsl)
    end

    def define_in_trash(dsl)
      dsl.count :in_trash, title: "In trash", description: CURRENT_TRASH_DESCRIPTION, expose: EXPOSE
    end

    def define_in_trash_by_type(dsl)
      dsl.breakdown :in_trash_by_type,
                    title: "In trash by type",
                    field: :recordable_type,
                    description: CURRENT_TRASH_DESCRIPTION,
                    expose: EXPOSE
    end

    def define_trashed_over_time(dsl)
      dsl.timeseries :trashed_over_time,
                     title: "Trashed over time",
                     field: :trashed_at,
                     description: CURRENT_TRASH_DESCRIPTION,
                     expose: EXPOSE
    end
  end
end
