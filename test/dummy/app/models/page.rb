class Page < ApplicationRecord
  include RecordingStudio::Capabilities::Trashable.to
end
