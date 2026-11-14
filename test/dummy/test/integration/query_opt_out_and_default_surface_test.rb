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

  test "kept_sql on the booted engine quotes the recordings table and a join alias" do
    quoted_child = RecordingStudio::Recording.connection.quote_table_name("child")
    quoted_recordings = RecordingStudio::Recording.connection.quote_table_name("recording_studio_recordings")

    assert_equal "(#{quoted_child}.trashed_at IS NULL)", RecordingStudio.kept_sql("child")
    assert_equal "(#{quoted_recordings}.trashed_at IS NULL)", RecordingStudio.kept_sql
    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioTrashable::RecordingScopes
    assert_equal RecordingStudio.kept_sql, RecordingStudio::Recording.recording_studio_trashable_kept_sql
    assert_equal RecordingStudio.kept_sql("child"), RecordingStudio::Recording.recording_studio_trashable_kept_sql("child")
    refute_respond_to RecordingStudio::Recording, :recording_studio_trashable_active
  end

  test "full engine Recording ancestor order matches main" do
    cache_classes = Rails.application.config.cache_classes
    assert_scopes_before_trashable_methods
    extension_ids = recording_extension_ids
    default_scope_count = RecordingStudio::Recording.default_scopes.size
    # Metrics replaces a resource on reload only when cache_classes is false.
    Rails.application.config.cache_classes = false

    Rails.application.reloader.reload!

    quoted_child = RecordingStudio::Recording.connection.quote_table_name("child")
    assert_scopes_before_trashable_methods
    assert_equal extension_ids, recording_extension_ids
    assert_equal default_scope_count, RecordingStudio::Recording.default_scopes.size
    assert_equal 0, default_scope_count
    assert_equal "(#{quoted_child}.trashed_at IS NULL)", RecordingStudio.kept_sql("child")
    assert_equal 1, RecordingStudio.kept_sql.scan("trashed_at").size
  ensure
    Rails.application.config.cache_classes = cache_classes
  end

  private

  def assert_scopes_before_trashable_methods
    ancestry = RecordingStudio::Recording.ancestors.map(&:name)
    scopes = "RecordingStudioTrashable::RecordingScopes"
    methods = "RecordingStudio::Trashable::Capabilities::Trashable::RecordingMethods"
    scopes_index = ancestry.index(scopes)
    methods_index = ancestry.index(methods)

    refute_nil scopes_index, "expected #{scopes} in Recording ancestors"
    refute_nil methods_index, "expected #{methods} in Recording ancestors"
    assert_operator scopes_index, :<, methods_index,
                    "expected RecordingScopes before RecordingMethods, got #{ancestry.first(8).inspect}"
  end

  def recording_extension_ids
    RecordingStudio.configuration.hooks.model_extensions_for(:recording).map(&:object_id)
  end
end
