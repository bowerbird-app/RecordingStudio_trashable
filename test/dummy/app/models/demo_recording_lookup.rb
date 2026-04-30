class DemoRecordingLookup
  TYPE_TABLES = {
    "Project" => "projects",
    "Folder" => "folders",
    "Page" => "pages"
  }.freeze

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
  end
end
