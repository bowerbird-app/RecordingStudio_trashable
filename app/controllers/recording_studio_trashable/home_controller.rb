# frozen_string_literal: true

module RecordingStudioTrashable
  class HomeController < ApplicationController
    def index
      @configuration = RecordingStudioTrashable.configuration
    end
  end
end
