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
    assert_includes text, "Permanently deletes this recording and everything under it."
    assert_includes text, "must already be in the trash"
    assert_includes text, "returns 422"
    assert_includes text, "returns 404"
  end

  def test_trash_restore_and_list_descriptions_name_the_endpoint
    trash = description(:trashable_trash)
    restore = description(:trashable_restore)
    list = description(:trashable_list_trash_bin)

    assert_includes trash, "every recording under it"
    assert_includes trash, "returns 422"
    assert_includes trash, "returns 404"
    assert_includes restore, "stay in the trash"
    assert_includes restore, "must already be in the trash"
    assert_includes restore, "recording_id"
    assert_includes restore, "returns 422"
    assert_includes description(:trashable_purge), "recording_id"
    assert_includes description(:trashable_purge), "still active"
    assert_includes list, "trash roots"
    assert_includes list, "newest first"
    assert_includes list, "per_page"
    assert_includes list, "label and recordable_type"
    assert_includes list, "recording_id"
    assert_includes list, "returns 422"
  end

  def test_api_descriptions_differ_from_mcp_copy
    NAMES.each do |name|
      api = description(name)
      mcp = RecordingStudioTrashable::McpCopy::Copy::DESCRIPTIONS.fetch(name)

      refute_equal mcp, api, name.to_s
      refute_includes api, "role"
      refute_includes api, "Use this when"
      refute_includes api, "so you can pick"
    end
  end

  def test_restore_and_purge_contracts_take_a_list_trash_bin_recording_id
    %i[trashable_restore trashable_purge].each do |name|
      field = RecordingStudioTrashable::Api::Catalog.contract_for(name).fetch(:fields).fetch(:recording_id)

      assert_equal false, field.fetch(:required), name.to_s
      assert_includes field.fetch(:description), "trash-bin record"
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
