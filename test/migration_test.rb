# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../db/migrate/20250101000001_add_trashed_at_to_recording_studio_recordings"

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
end
