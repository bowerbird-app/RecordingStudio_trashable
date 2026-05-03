# frozen_string_literal: true

class AddTrashRootToRecordingStudioRecordings < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_recordings, :trash_root, :boolean, default: false, null: false unless column_exists?(:recording_studio_recordings, :trash_root)
    add_index :recording_studio_recordings, %i[trashed_at trash_root], name: "idx_rs_recordings_trashed_at_trash_root" unless index_exists?(:recording_studio_recordings, %i[trashed_at trash_root], name: "idx_rs_recordings_trashed_at_trash_root")
  end
end