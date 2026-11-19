# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_gemspec_does_not_depend_on_recording_studio_api
    gemspec = File.read(File.expand_path("recording_studio_trashable.gemspec", ROOT))

    refute_includes gemspec, "recording_studio_api"
  end

  def test_register_is_a_no_op_without_recording_studio_api
    skip "Recording Studio API is loaded" if defined?(::RecordingStudioApi)

    RecordingStudioTrashable::Api.register!
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioTrashable::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_trashable.api"
    assert_includes names, "recording_studio_trashable.metrics"
  end

  def test_metrics_stay_on_operations
    source = File.read(File.expand_path("lib/recording_studio_trashable/metrics.rb", ROOT))

    assert_includes source, "RecordingStudioTrashable::Api::Access.can_view?"
    assert_includes source, "API = :operations"
    refute_includes source, "register_capability_action"
  end

  def test_catalog_copy_states_purpose_without_access_roles
    actions = RecordingStudioTrashable::Api::Catalog::ACTIONS
    list_fields = RecordingStudioTrashable::Api::Catalog::LIST_TRASH_BIN_CONTRACT.fetch(:fields)
    recording_id = RecordingStudioTrashable::Api::Catalog.contract_for(:trashable_restore)
                                                         .fetch(:fields).fetch(:recording_id)

    trash = actions.fetch(:trashable_trash)
    assert_equal "Trash", trash[:title]
    assert_equal "Move this recording to the trash.", trash[:summary]
    assert_includes trash[:description], "Nested recordings under it are trashed"
    assert_includes trash[:description], "already in the trash is rejected as not found"
    assert_includes trash[:description], "Returns this recording"

    restore = actions.fetch(:trashable_restore)
    assert_equal "Restore", restore[:title]
    assert_equal "Restore this recording from the trash.", restore[:summary]
    assert_includes restore[:description], "trashed on their own stay in the trash"
    assert_includes restore[:description], "not in the trash is rejected"
    assert_includes restore[:description], "Returns this recording"

    purge = actions.fetch(:trashable_purge)
    assert_equal "Purge", purge[:title]
    assert_equal "Permanently delete this trashed recording.", purge[:summary]
    assert_includes purge[:description], "permanently deletes this recording and nested trash"
    assert_includes purge[:description], "still live, is rejected"
    assert_includes purge[:description], "purged true"

    list = actions.fetch(:trashable_list_trash_bin)
    assert_equal "List trash bin", list[:title]
    assert_equal "List recordings people moved to trash under this recording.", list[:summary]
    assert_includes list[:description], "stay hidden"
    assert_includes list[:description], "Returns records"
    assert_includes list_fields.fetch(:q)[:description], "name, title, type, or id"
    assert_includes list_fields.fetch(:page)[:description], "counting from 1"
    assert_includes list_fields.fetch(:per_page)[:description], "capped at 100"
    assert_includes recording_id.fetch(:description), "List trash bin"

    copy_blobs(actions, list_fields, recording_id).each do |blob|
      refute_match(/\bAccess\b/, blob)
      refute_match(/\brole\b/i, blob)
      refute_match(/\badmin\b/i, blob)
      refute_includes blob, ":edit"
    end
  end

  private

  def copy_blobs(actions, list_fields, recording_id)
    actions.map do |name, spec|
      responses = RecordingStudioTrashable::Api::Catalog.openapi_for(name).fetch(:responses)
      [
        spec[:title],
        spec[:summary],
        spec[:description],
        recording_id.fetch(:description),
        list_fields.values.map { |field| field[:description] },
        responses.values.map { |response| response[:description] }
      ].join(" ")
    end
  end
end
