class Page < ApplicationRecord
  recording_studio_recordable label: "Page", plural_label: "Pages", root: false,
                              allowed_parent_types: ["Project", "Folder", "Page"]

  include RecordingStudio::Capabilities::Trashable.to
end
