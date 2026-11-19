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
  ROLE_WORDS = [
    /\bAccess\b/,
    /\brole\b/i,
    /\badmin\b/i,
    /:edit/,
    /\bedit role\b/i,
    /\badmin role\b/i
  ].freeze

  def test_openapi_titles_match_main_short_verbs
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

  def test_trash_description_keeps_main_facts
    text = description(:trashable_trash)

    assert_includes text, "Nested recordings under it are trashed"
    assert_includes text, "already in the trash is rejected as not found"
    assert_includes text, "Calling trash again after a successful trash is rejected the same way"
    assert_includes text, "Returns this recording"
    assert_includes text, "id, type, parent_id, root_id, created_at, and updated_at"
    assert_includes text, "trashed_at is not a field"
    assert_includes text, "label and recordable_type"
    assert_includes text, "recording_id when called on the parent"
  end

  def test_restore_description_keeps_recording_id_and_422
    text = description(:trashable_restore)

    assert_includes text, "trashed on their own stay in the trash"
    assert_includes text, "Pass optional recording_id"
    assert_includes text, "List trash bin"
    assert_includes text, "belong under this recording"
    assert_includes text, "Without recording_id, this restores the recording in the path"
    assert_includes text, "not in the trash is rejected"
    refute_includes text, "not in the trash is rejected as not found"
    assert_includes text, "Calling restore again after a successful restore is rejected the same way"
    assert_includes text, "Returns this recording"
    assert_includes text, "same fields Trash returns"
  end

  def test_purge_description_keeps_recording_id_and_422
    text = description(:trashable_purge)

    assert_includes text, "cannot be restored"
    assert_includes text, "permanently deletes this recording and nested trash"
    assert_includes text, "already in the trash"
    assert_includes text, "Pass optional recording_id"
    assert_includes text, "Without recording_id, this purges the recording in the path"
    assert_includes text, "still live, is rejected"
    refute_includes text, "still live, is rejected as not found"
    assert_includes text, "another call for the same id is rejected as not found"
    assert_includes text, "purged true"
  end

  def test_list_description_keeps_search_order_and_shape
    text = description(:trashable_list_trash_bin)

    assert_includes text, "stay hidden"
    assert_includes text, "name, title, type, or id"
    assert_includes text, "ignores case"
    assert_includes text, "trashed_at descending, then id descending"
    assert_includes text, "no page number and no total count"
    assert_includes text, "page or per_page"
    assert_includes text, "Calling list again returns the current page"
    assert_includes text, "Returns records"
    assert_includes text, "label and recordable_type"
  end

  def test_restore_and_purge_contracts_take_a_list_trash_bin_recording_id
    %i[trashable_restore trashable_purge].each do |name|
      field = RecordingStudioTrashable::Api::Catalog.contract_for(name).fetch(:fields).fetch(:recording_id)

      assert_equal false, field.fetch(:required), name.to_s
      assert_includes field.fetch(:description), "List trash bin"
      assert_includes field.fetch(:description), "Optional"
      assert_includes field.fetch(:description), "Omit it"
      assert_includes field.fetch(:description), "belong under this recording"
    end

    assert_empty RecordingStudioTrashable::Api::Catalog.contract_for(:trashable_trash).fetch(:fields)
  end

  def test_copy_has_no_access_or_role_wording
    recording_id = RecordingStudioTrashable::Api::Catalog.contract_for(:trashable_restore)
                                                         .fetch(:fields).fetch(:recording_id).fetch(:description)
    list_fields = RecordingStudioTrashable::Api::Catalog::LIST_TRASH_BIN_CONTRACT.fetch(:fields)
    blobs = NAMES.map { |name| copy_blob(name) }
    blobs << recording_id
    blobs.concat(list_fields.values.map { |field| field.fetch(:description) })

    blobs.each do |blob|
      ROLE_WORDS.each do |pattern|
        refute_match pattern, blob
      end
    end
  end

  private

  def openapi(name)
    RecordingStudioTrashable::Api::Catalog.openapi_for(name)
  end

  def description(name)
    openapi(name).fetch(:description)
  end

  def copy_blob(name)
    spec = RecordingStudioTrashable::Api::Catalog::ACTIONS.fetch(name)
    responses = openapi(name).fetch(:responses)
    [
      spec.fetch(:title),
      spec.fetch(:summary),
      spec.fetch(:description),
      responses.values.map { |response| response[:description] }
    ].join(" ")
  end
end
