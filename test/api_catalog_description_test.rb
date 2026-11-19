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
    trashable_trash: "Trash - Trash",
    trashable_restore: "Trash - Restore",
    trashable_purge: "Trash - Purge",
    trashable_list_trash_bin: "Trash - List trash bin"
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

    assert_includes text, "cannot be restored"
    assert_includes text, "permanently deletes this recording and nested trash"
    assert_includes text, "already in the trash"
    assert_includes text, "trashable_list_trash_bin"
  end

  def test_trash_restore_and_list_descriptions_name_the_choice
    trash = description(:trashable_trash)
    restore = description(:trashable_restore)
    list = description(:trashable_list_trash_bin)

    assert_includes trash, "Nested recordings under it are trashed"
    assert_includes trash, "already in the trash is rejected as not found"
    assert_includes trash, "Returns this recording"
    assert_includes restore, "trashed on their own stay in the trash"
    assert_includes restore, "not in the trash is rejected"
    assert_includes restore, "Returns this recording"
    assert_includes description(:trashable_purge), "purged true"
    assert_includes list, "stay hidden"
    assert_includes list, "Returns records"
    assert_includes list, "q, page, or per_page"
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
