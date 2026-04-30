# frozen_string_literal: true

require "test_helper"

class RecordingStudioTrashableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioTrashable::VERSION
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

    assert_includes source, "Workspace trash bin"
    assert_includes source, "Project trash bin"
    assert_includes source, "Adding to a recordable"
    assert_includes source, "Cascading"
    assert_includes source, "Methods"
  end
end
