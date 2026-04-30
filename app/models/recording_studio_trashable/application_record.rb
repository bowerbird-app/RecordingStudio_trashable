# frozen_string_literal: true

module RecordingStudioTrashable
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
