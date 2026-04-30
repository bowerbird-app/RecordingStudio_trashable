# frozen_string_literal: true

class AddTrashedAtToRecordingStudioRecordings < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_recordings, :trashed_at, :datetime unless column_exists?(:recording_studio_recordings, :trashed_at)
    add_index :recording_studio_recordings, :trashed_at unless index_exists?(:recording_studio_recordings, :trashed_at)
  end
end
