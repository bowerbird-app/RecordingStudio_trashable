# frozen_string_literal: true

require_relative "../test_helper"

class QueryOptOutAndDefaultSurfaceTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    sign_in @user
  end

  test "default engine path keeps live_search importmap pin and modulepreload" do
    importmap_paths = Rails.application.config.importmap.paths.map(&:to_s)
    asset_paths = Rails.application.config.assets.paths.map(&:to_s)
    engine_importmap = RecordingStudioTrashable::Engine.root.join("config/importmap.rb").to_s
    engine_js = RecordingStudioTrashable::Engine.root.join("app/javascript").to_s

    assert_includes importmap_paths, engine_importmap
    assert_includes asset_paths, engine_js
    assert RecordingStudio.registered_capabilities.key?(:trashable)
    assert_includes ActionView::Base.included_modules, RecordingStudioTrashable::CopyHelper
    assert RecordingStudioMetrics.find("trash.in_trash")

    get recording_studio_trashable.root_path
    assert_response :success

    body = response.body
    assert_includes body, "controllers/recording_studio_trashable/live_search_controller"
    assert_match(
      %r{rel="modulepreload"[^>]+recording_studio_trashable/controllers/live_search_controller},
      body
    )
  end

  test "query helpers on Recording match the sibling SQL contract under the default boot" do
    assert_equal '"child"."trashed_at" IS NULL',
                 RecordingStudio::Recording.recording_studio_trashable_kept_sql("child")
    assert_equal '"recording_studio_recordings"."trashed_at" IS NULL',
                 RecordingStudio::Recording.recording_studio_trashable_kept_sql
    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioTrashable::RecordingScopes
  end
end
