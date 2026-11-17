# frozen_string_literal: true

require "test_helper"

class ApiCatalogDescriptionTest < Minitest::Test
  NAMES = %i[
    trashable_trash
    trashable_restore
    trashable_purge
    trashable_list_trash_bin
  ].freeze
  TITLES = {
    trashable_trash: "Trash",
    trashable_restore: "Restore",
    trashable_purge: "Purge",
    trashable_list_trash_bin: "List trash bin"
  }.freeze

  def test_openapi_titles_are_plain_names
    TITLES.each do |name, title|
      assert_equal title, openapi(name).fetch(:title), name.to_s
    end
  end

  def test_openapi_tag_suffix_is_trash
    NAMES.each do |name|
      assert_equal "Trash", openapi(name).fetch(:tag_suffix), name.to_s
    end
  end

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
    assert_includes trash, "label and recordable_type"
    assert_includes restore, "stay trashed"
    assert_includes restore, "recording_id"
    assert_includes restore, "called on the parent"
    assert_includes description(:trashable_purge), "recording_id"
    assert_includes description(:trashable_purge), "label and recordable_type"
    assert_includes list, "top-level trashed items"
    assert_includes list, "newest first"
    assert_includes list, "per_page"
    assert_includes list, "label and recordable_type"
    assert_includes list, "recording_id"
  end

  def test_restore_and_purge_contracts_take_a_list_trash_bin_recording_id
    %i[trashable_restore trashable_purge].each do |name|
      field = RecordingStudioTrashable::Api::Catalog.contract_for(name).fetch(:fields).fetch(:recording_id)

      assert_equal false, field.fetch(:required), name.to_s
      assert_includes field.fetch(:description), "List trash bin"
    end

    assert_empty RecordingStudioTrashable::Api::Catalog.contract_for(:trashable_trash).fetch(:fields)
  end

  private

  def openapi(name)
    RecordingStudioTrashable::Api::Catalog.openapi_for(name)
  end

  def description(name)
    openapi(name).fetch(:description)
  end
end
