# frozen_string_literal: true

require "test_helper"
require_relative "../db/migrate/20250101000001_add_trashed_at_to_recording_studio_recordings"

class MigrationTest < Minitest::Test
  def test_add_trashed_at_migration_adds_missing_column_and_index_independently
    migration = AddTrashedAtToRecordingStudioRecordings.new
    calls = []

    migration.stub(:column_exists?, true) do
      migration.stub(:index_exists?, false) do
        migration.stub(:add_column, ->(*args) { calls << [:add_column, args] }) do
          migration.stub(:add_index, ->(*args) { calls << [:add_index, args] }) do
            migration.change
          end
        end
      end
    end

    refute calls.any? { |name, _| name == :add_column }
    assert_equal [[:add_index, [:recording_studio_recordings, :trashed_at]]], calls
  end
end
