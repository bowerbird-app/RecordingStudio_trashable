# frozen_string_literal: true

class AddTrashedAtToRecordingStudioRecordings < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:recording_studio_recordings, :trashed_at)

    add_column :recording_studio_recordings, :trashed_at, :datetime
    add_index :recording_studio_recordings, :trashed_at
  end
end
