# frozen_string_literal: true

require "test_helper"

class ImportmapPreloadTest < ActiveSupport::TestCase
  LIVE_SEARCH_CONTROLLER = "controllers/recording_studio_trashable/live_search_controller"

  test "trashable live_search_controller is pinned and not modulepreloaded" do
    importmap = Rails.application.importmap
    resolver = ApplicationController.helpers
    imports = JSON.parse(importmap.to_json(resolver: resolver)).fetch("imports")

    assert imports.key?(LIVE_SEARCH_CONTROLLER)

    %w[application landing].each do |entry|
      preloaded = importmap.preloaded_module_packages(
        resolver: resolver,
        entry_point: entry,
        cache_key: "trashable-preload-#{entry}"
      )
      preloaded_names = preloaded.values.map(&:name)

      refute_includes preloaded_names, LIVE_SEARCH_CONTROLLER
    end
  end
end
