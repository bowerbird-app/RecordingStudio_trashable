# frozen_string_literal: true

require "test_helper"

class ApiCatalogDescriptionTest < Minitest::Test
  NAMES = %i[
    trashable_trash
    trashable_restore
    trashable_purge
    trashable_list_trash_bin
  ].freeze

  def test_each_action_description_says_what_it_returns
    NAMES.each do |name|
      assert_includes description(name), "Returns", "#{name} should say what it returns"
    end
  end

  def test_purge_description_warns_it_cannot_be_undone
    text = description(:trashable_purge)

    assert_includes text, "cannot be undone"
    assert_includes text, "Permanently deletes this trashed item and everything trashed under it."
    assert_includes text, "already in the trash"
    assert_includes text, "List trash bin"
  end

  def test_trash_restore_and_list_descriptions_name_the_choice
    trash = description(:trashable_trash)
    restore = description(:trashable_restore)
    list = description(:trashable_list_trash_bin)

    assert_includes trash, "everything under the item"
    assert_includes trash, "Restore can undo it."
    assert_includes restore, "stay trashed"
    assert_includes list, "top-level trashed items"
    assert_includes list, "newest first"
    assert_includes list, "per_page"
  end

  private

  def description(name)
    RecordingStudioTrashable::Api::Catalog.openapi_for(name).fetch(:description)
  end
end
