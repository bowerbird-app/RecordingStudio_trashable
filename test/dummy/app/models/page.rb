class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false,
                              allowed_parent_types: %w[Workspace Project Folder]

  include RecordingStudio::Capabilities::Trashable.to
end
