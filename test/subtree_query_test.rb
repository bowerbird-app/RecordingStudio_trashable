# frozen_string_literal: true

require "test_helper"
require "active_record"

class SubtreeQueryTest < Minitest::Test
  class SearchPageRecordable
    def self.table_name = "pages"
    def self.column_names = %w[id title]
    def self.primary_key = "id"
  end

  class SearchFolderRecordable
    def self.table_name = "folders"
    def self.column_names = %w[id name]
    def self.primary_key = "id"
  end

  class SearchAccessRecordable
    def self.table_name = "recording_studio_accesses"
    def self.column_names = %w[id role]
    def self.primary_key = "id"
  end

  class FakeConnection
    def quote(value)
      "'#{value.to_s.gsub("'", "''")}'"
    end

    def quote_table_name(name)
      %("#{name}")
    end

    def quote_column_name(name)
      %("#{name}")
    end
  end

  class FakeRelation
    class << self
      attr_accessor :last_to_a_relation
    end

    attr_reader :where_arguments, :or_relations

    def initialize(types:, rows: [], where_arguments: [], or_relations: [])
      @types = types
      @rows = rows
      @where_arguments = where_arguments
      @or_relations = or_relations
    end

    def where(argument)
      self.class.new(
        types: @types,
        rows: @rows,
        where_arguments: where_arguments + [argument],
        or_relations: or_relations
      )
    end

    def or(other)
      self.class.new(
        types: @types,
        rows: @rows,
        where_arguments: where_arguments,
        or_relations: or_relations + [other]
      )
    end

    def reorder(*)
      self
    end

    def unscope(*)
      self
    end

    def distinct
      self
    end

    def pluck(attribute)
      raise "unexpected attribute" unless attribute == :recordable_type

      @types
    end

    def to_a
      self.class.last_to_a_relation = self
      @rows
    end
  end

  class FakeRecordingModel
    class << self
      attr_accessor :base_relation
    end

    def self.none
      FakeRelation.new(types: [], rows: [])
    end

    def self.recording_studio_trashable_trash_roots
      base_relation
    end

    def self.connection
      @connection ||= FakeConnection.new
    end

    def self.table_name
      "recording_studio_recordings"
    end
  end

  def setup
    FakeRelation.last_to_a_relation = nil
  end

  def test_trashed_recordings_for_returns_none_without_a_scope_recording
    RecordingStudioTrashable::SubtreeQuery.stub(:recording_model, FakeRecordingModel) do
      assert_empty RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for(nil)
    end
  end

  def test_recordings_for_walks_the_subtree_breadth_first
    root = Struct.new(:id).new(1)
    child_one = Struct.new(:id).new(2)
    child_two = Struct.new(:id).new(3)
    grandchild = Struct.new(:id).new(4)
    calls = []

    RecordingStudioTrashable::SubtreeQuery.stub(:child_recordings_for, lambda { |frontier|
      calls << frontier

      case frontier
      when [1] then [child_one, child_two]
      when [2, 3] then [grandchild]
      else []
      end
    }) do
      assert_equal [root, child_one, child_two, grandchild], RecordingStudioTrashable::SubtreeQuery.recordings_for(root)
      assert_equal(
        [child_one, child_two, grandchild],
        RecordingStudioTrashable::SubtreeQuery.recordings_for(root, include_root: false)
      )
    end

    assert_equal [[1], [2, 3], [4], [1], [2, 3], [4]], calls
  end

  def test_trashed_recordings_for_query_limits_to_scope_and_builds_search_sql
    FakeRecordingModel.base_relation = FakeRelation.new(
      types: %w[SubtreeQueryTest::SearchPageRecordable SubtreeQueryTest::SearchFolderRecordable SubtreeQueryTest::SearchAccessRecordable],
      rows: [:match]
    )
    root_recording = Struct.new(:id).new("root-123")

    RecordingStudioTrashable::SubtreeQuery.stub(:recording_model, FakeRecordingModel) do
      result = RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(root_recording, query: "Mix")

      assert_equal [:match], result.to_a
    end

    final_relation = FakeRelation.last_to_a_relation
    assert_equal({ id: "root-123" }, final_relation.where_arguments.first)
    assert_equal({ root_recording_id: "root-123" }, final_relation.or_relations.first.where_arguments.first)

    search_sql = final_relation.where_arguments.last
    assert_includes search_sql, 'LOWER("recording_studio_recordings"."recordable_type") LIKE '
    assert_includes search_sql, 'CAST("recording_studio_recordings"."id" AS TEXT) LIKE '
    assert_includes search_sql, 'FROM "pages"'
    assert_includes search_sql, '"pages"."title"'
    assert_includes search_sql, 'FROM "folders"'
    assert_includes search_sql, '"folders"."name"'
    refute_includes search_sql, "recording_studio_accesses"
    assert_includes search_sql, "'%mix%'"
  end

  def test_trashed_recordings_for_query_skips_search_sql_for_blank_queries
    FakeRecordingModel.base_relation = FakeRelation.new(types: [], rows: [:match])
    root_recording = Struct.new(:id).new("root-123")

    RecordingStudioTrashable::SubtreeQuery.stub(:recording_model, FakeRecordingModel) do
      result = RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(root_recording, query: "   ")

      assert_equal [:match], result.to_a
    end

    final_relation = FakeRelation.last_to_a_relation
    assert_equal 1, final_relation.where_arguments.length
    assert_equal({ id: "root-123" }, final_relation.where_arguments.first)
  end

  def test_trashed_recordings_for_query_escapes_wildcards_in_the_search_term
    FakeRecordingModel.base_relation = FakeRelation.new(
      types: %w[SubtreeQueryTest::SearchPageRecordable],
      rows: [:match]
    )
    root_recording = Struct.new(:id).new("root-123")

    RecordingStudioTrashable::SubtreeQuery.stub(:recording_model, FakeRecordingModel) do
      RecordingStudioTrashable::SubtreeQuery.trashed_recordings_for_query(root_recording, query: "100%_Mix").to_a
    end

    search_sql = FakeRelation.last_to_a_relation.where_arguments.last
    assert_includes search_sql, "%100\\%\\_mix%"
  end
end
