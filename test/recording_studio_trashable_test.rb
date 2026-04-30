# frozen_string_literal: true

require "test_helper"

class RecordingStudioTrashableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioTrashable::VERSION
  end

  def test_version_matches_latest_changelog_release
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))

    assert_includes changelog, "## [#{RecordingStudioTrashable::VERSION}]"
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudioTrashable::Engine
  end

  def test_page_capability_alias_is_registered
    assert_equal RecordingStudio::Trashable::Capabilities::Trashable, RecordingStudio::Capabilities::Trashable
  end

  def test_dummy_sidebar_mentions_showcase_pages_and_trash_bins
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    source = File.read(sidebar_path)

    assert_includes source, "main_app.root_path"
    assert_includes source, "main_app.showcase_path"
    assert_includes source, "main_app.destroy_user_session_path"
    assert_includes source, "Workspace trash bin"
    assert_includes source, "Project trash bin"
    assert_includes source, "Adding to a recordable"
    assert_includes source, "Cascading"
    assert_includes source, "Methods"
  end

  def test_dummy_current_supports_actor_and_impersonator
    current_model = File.read(File.expand_path("dummy/app/models/current.rb", __dir__))

    assert_includes current_model, "attribute :actor, :impersonator"
  end
end
