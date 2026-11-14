# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioTrashable
  module RecordingScopes
    FILTERS = %i[active trashed all].freeze

    extend ActiveSupport::Concern

    included do
      scope :recording_studio_trashable_trashed, -> { unscope(where: :trashed_at).where.not(trashed_at: nil) }
      scope :recording_studio_trashable_trash_roots, -> { recording_studio_trashable_trashed.where(trash_root: true) }
      scope :recording_studio_trashable_filter, lambda { |filter|
        case filter.to_sym
        when :active then kept
        when :trashed then recording_studio_trashable_trashed
        when :all then unscope(where: :trashed_at)
        else
          raise ArgumentError,
                "Unknown trash filter #{filter.inspect}. Expected one of: #{FILTERS.join(', ')}"
        end
      }
      scope :recording_studio_trashable_trash_bin, lambda {
        recording_studio_trashable_trash_roots.reorder(trashed_at: :desc, updated_at: :desc)
      }
    end

    def recording_studio_trashable_trashed?
      trashed_at.present?
    end

    def recording_studio_trashable_kept?
      !recording_studio_trashable_trashed?
    end

    def recording_studio_trashable_void!(time: Time.current)
      RecordingStudioTrashable.void_recording!(self, time: time)
    end
  end
end
