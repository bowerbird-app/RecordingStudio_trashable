# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../db/migrate/20250101000001_add_trashed_at_to_recording_studio_recordings"
require_relative "../db/migrate/20250101000003_add_trash_root_to_recording_studio_recordings"

class MigrationTest < Minitest::Test
  def test_add_trashed_at_migration_adds_missing_column_and_index_independently
    migration = AddTrashedAtToRecordingStudioRecordings.new
    calls = []

    migration.singleton_class.class_eval do
      define_method(:column_exists?) { |*_args| true }
      define_method(:index_exists?) { |*_args| false }
      define_method(:add_column) { |*args| calls << [:add_column, args] }
      define_method(:add_index) { |*args| calls << [:add_index, args] }
    end

    migration.change

    refute(calls.any? { |name, _| name == :add_column })
    assert_equal [[:add_index, %i[recording_studio_recordings trashed_at]]], calls
  end

  def test_add_trash_root_migration_adds_column_index_and_backfills
    migration = AddTrashRootToRecordingStudioRecordings.new
    calls = []

    migration.singleton_class.class_eval do
      define_method(:table_exists?) { |*_args| true }
      define_method(:column_exists?) { |*_args| false }
      define_method(:index_exists?) { |*_args, **_kwargs| false }
      define_method(:add_column) { |*args, **kwargs| calls << [:add_column, args, kwargs] }
      define_method(:add_index) { |*args, **kwargs| calls << [:add_index, args, kwargs] }
      define_method(:execute) { |sql| calls << [:execute, sql] }
    end

    migration.up

    assert_equal(
      [
        :add_column,
        %i[recording_studio_recordings trash_root boolean],
        { default: false, null: false }
      ],
      calls[0]
    )
    assert_equal(
      [
        :add_index,
        [:recording_studio_recordings, %i[trashed_at trash_root]],
        { name: "idx_rs_recordings_trashed_at_trash_root" }
      ],
      calls[1]
    )
    assert_includes calls[2].last, "SET trash_root = CASE"
    assert_includes calls[2].last, "parents.id = recordings.parent_recording_id"
  end

  def test_add_trash_root_migration_down_removes_index_and_column_when_present
    migration = AddTrashRootToRecordingStudioRecordings.new
    calls = []

    migration.singleton_class.class_eval do
      define_method(:table_exists?) { |*_args| true }
      define_method(:column_exists?) { |*_args| true }
      define_method(:index_exists?) { |*_args, **_kwargs| true }
      define_method(:remove_index) { |*args, **kwargs| calls << [:remove_index, args, kwargs] }
      define_method(:remove_column) { |*args| calls << [:remove_column, args] }
    end

    migration.down

    assert_equal(
      [
        :remove_index,
        [:recording_studio_recordings],
        { name: "idx_rs_recordings_trashed_at_trash_root" }
      ],
      calls[0]
    )
    assert_equal [:remove_column, %i[recording_studio_recordings trash_root]], calls[1]
  end
end
