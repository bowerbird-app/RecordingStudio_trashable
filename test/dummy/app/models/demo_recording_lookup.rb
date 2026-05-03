class DemoRecordingLookup
  TYPE_TABLES = {
    "Project" => "projects",
    "Folder" => "folders",
    "Page" => "pages"
  }.freeze

  DEFAULT_HOME_TABLE_LIMIT = 2

  class << self
    def workspace_root
      RecordingStudio::Recording.recording_studio_trashable_including_trashed.find_by(
        recordable_type: "Workspace",
        parent_recording_id: nil
      )
    end

    def by_slug(type:, slug:)
      type_name = type.to_s
      table = TYPE_TABLES.fetch(type_name)

      RecordingStudio::Recording.recording_studio_trashable_including_trashed
                               .joins("INNER JOIN #{table} ON #{table}.id = recording_studio_recordings.recordable_id")
                               .find_by("recording_studio_recordings.recordable_type = ? AND #{table}.slug = ?",
                                        type_name, slug)
    end

    def recent_projects(root_recording, limit: DEFAULT_HOME_TABLE_LIMIT)
      subtree_relation_for(root_recording)
        .recording_studio_trashable_active
        .where(recordable_type: "Project")
        .reorder(updated_at: :desc, id: :desc)
        .limit(limit)
        .to_a
    end

    def recent_active_pages(root_recording, limit: DEFAULT_HOME_TABLE_LIMIT)
      subtree_relation_for(root_recording)
        .recording_studio_trashable_active
        .where(recordable_type: "Page")
        .reorder(updated_at: :desc, id: :desc)
        .limit(limit)
        .to_a
    end

    def recent_trash_roots(root_recording, limit: DEFAULT_HOME_TABLE_LIMIT)
      subtree_relation_for(root_recording)
        .recording_studio_trashable_trash_roots
        .where(recordable_type: "Page")
        .reorder(trashed_at: :desc, id: :desc)
        .limit(limit)
        .to_a
    end

    private

    def subtree_relation_for(root_recording)
      return RecordingStudio::Recording.none unless root_recording

      RecordingStudio::Recording.recording_studio_trashable_including_trashed.where(root_recording_id: root_recording.id)
    end
  end
end
