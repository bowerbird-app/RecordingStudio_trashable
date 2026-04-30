# frozen_string_literal: true

module RecordingStudioTrashable
  class RetentionSetting < ApplicationRecord
    self.table_name = "recording_studio_trashable_retention_settings"

    belongs_to :recording, class_name: "RecordingStudio::Recording"

    validates :purge_after_days,
              numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  end
end
