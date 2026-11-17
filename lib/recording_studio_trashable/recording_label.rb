# frozen_string_literal: true

module RecordingStudioTrashable
  module RecordingLabel
    module_function

    def for(recording)
      recordable = recording.recordable
      return recordable.title if recordable.respond_to?(:title) && recordable.title.present?
      return recordable.name if recordable.respond_to?(:name) && recordable.name.present?

      "#{recording.recordable_type} ##{recording.id.to_s.first(8)}"
    end
  end
end
