# frozen_string_literal: true

require "test_helper"

class RetentionPurgerTest < Minitest::Test
  class FakeRelation
    def initialize(records)
      @records = records
    end

    def where(conditions)
      ids = Array(conditions.fetch(:parent_recording_id))
      self.class.new(@records.select { |record| ids.include?(record.parent_recording_id) })
    end

    def reorder(*)
      self
    end

    def lock
      FakeRecording.lock_proxy ||= FakeLock.new(@records.index_by(&:id))
    end

    def to_a
      @records
    end
  end

  class FakeLock
    def initialize(records)
      @records = records
    end

    def find(id)
      @records.fetch(id)
    end
  end

  class FakeRecording
    include RecordingStudio::Trashable::Capabilities::Trashable::RecordingMethods

    class << self
      attr_accessor :records, :lock_proxy, :destroyed_ids

      def transaction
        yield
      end

      def lock
        self.lock_proxy ||= FakeLock.new(records)
      end

      def recording_studio_trashable_including_trashed
        FakeRelation.new(records.values)
      end
    end

    attr_accessor :id, :parent_recording_id, :recordable_type, :trashed_at, :logged_events

    def initialize(id:, parent_recording_id: nil, recordable_type: "Page", trashed_at: nil)
      @id = id
      @parent_recording_id = parent_recording_id
      @recordable_type = recordable_type
      @trashed_at = trashed_at
      @logged_events = []
      self.class.records ||= {}
      self.class.records[id] = self
    end

    # rubocop:disable Naming/PredicateMethod
    def update!(attributes)
      self.trashed_at = attributes[:trashed_at] if attributes.key?(:trashed_at)
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def destroy!
      self.class.destroyed_ids ||= []
      self.class.destroyed_ids << id
      self.class.records.delete(id)
    end

    def log_event!(**attributes)
      logged_events << attributes
    end

    def reload
      self
    end

    def assert_capability!(capability)
      raise "unexpected capability" unless capability == :trashable
    end
  end

  def setup
    FakeRecording.records = {}
    FakeRecording.lock_proxy = nil
    FakeRecording.destroyed_ids = []
  end

  def teardown
    FakeRecording.records = {}
    FakeRecording.lock_proxy = nil
    FakeRecording.destroyed_ids = []
  end

  def test_purge_due_recordings_purges_leaf_first
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 10.days)
    child = FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 9.days)
    fresh = FakeRecording.new(id: "fresh", trashed_at: Time.now - 1.day)

    RecordingStudioTrashable::SubtreeQuery.stub(:recordings_for, [parent, child, fresh]) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, ->(recording:, **) { recording.id != "fresh" }) do
        RecordingStudioTrashable.stub(:authorized?, true) do
          result = RecordingStudioTrashable.purge_due_recordings(scope_recording: :workspace, actor: :system)

          assert_equal %w[child parent], FakeRecording.destroyed_ids
          assert_equal %w[child parent], result.purged_recordings.map(&:id)
          assert_empty result.skipped_recordings
          assert_empty result.would_purge_recordings
          assert_equal "recording_studio_trashable_retention", child.logged_events.first[:metadata][:source]
        end
      end
    end
  end

  def test_purge_due_recordings_skips_parent_records_that_still_have_descendants
    FakeRecording.new(id: "parent", trashed_at: Time.now - 10.days)
    FakeRecording.new(id: "child", parent_recording_id: "parent")

    RecordingStudioTrashable::SubtreeQuery.stub(:recordings_for, FakeRecording.records.values) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, true) do
        RecordingStudioTrashable.stub(:authorized?, true) do
          result = RecordingStudioTrashable.purge_due_recordings(scope_recording: :workspace, actor: :system)

          assert_empty result.purged_recordings
          assert_equal ["parent"], result.skipped_recordings.map(&:id)
          assert_empty result.would_purge_recordings
        end
      end
    end
  end

  def test_purge_due_recordings_skips_parent_until_trashed_descendants_are_due
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 10.days)
    child = FakeRecording.new(id: "fresh-child", parent_recording_id: "parent", trashed_at: Time.now - 1.day)

    RecordingStudioTrashable::SubtreeQuery.stub(:recordings_for, [parent, child]) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, ->(recording:, **) { recording.id == "parent" }) do
        RecordingStudioTrashable.stub(:authorized?, true) do
          result = RecordingStudioTrashable.purge_due_recordings(scope_recording: :workspace, actor: :system)

          assert_empty FakeRecording.destroyed_ids
          assert_empty result.purged_recordings
          assert_equal ["parent"], result.skipped_recordings.map(&:id)
          assert_empty result.would_purge_recordings
        end
      end
    end
  end

  def test_purge_due_recordings_skips_parent_until_deep_trashed_descendants_are_due
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 10.days)
    child = FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 10.days)
    grandchild = FakeRecording.new(id: "fresh-grandchild", parent_recording_id: "child", trashed_at: Time.now - 1.day)

    RecordingStudioTrashable::SubtreeQuery.stub(:recordings_for, [parent, child, grandchild]) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, ->(recording:, **) { recording.id != "fresh-grandchild" }) do
        RecordingStudioTrashable.stub(:authorized?, true) do
          result = RecordingStudioTrashable.purge_due_recordings(scope_recording: :workspace, actor: :system)

          assert_empty FakeRecording.destroyed_ids
          assert_empty result.purged_recordings
          assert_equal %w[child parent], result.skipped_recordings.map(&:id)
          assert_empty result.would_purge_recordings
        end
      end
    end
  end

  def test_purge_due_recordings_dry_run_collects_would_purge_without_destroying_records
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 10.days)
    child = FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 9.days)

    RecordingStudioTrashable::SubtreeQuery.stub(:recordings_for, [parent, child]) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, true) do
        RecordingStudioTrashable.stub(:authorized?, true) do
          result = RecordingStudioTrashable.purge_due_recordings(
            scope_recording: :workspace,
            actor: :system,
            dry_run: true
          )

          assert_empty FakeRecording.destroyed_ids
          assert_empty result.purged_recordings
          assert_empty result.skipped_recordings
          assert_equal %w[child parent], result.would_purge_recordings.map(&:id)
          assert_empty child.logged_events
        end
      end
    end
  end

  def test_purge_due_recordings_dry_run_skips_parent_with_non_due_trashed_descendants
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 10.days)
    child = FakeRecording.new(id: "fresh-child", parent_recording_id: "parent", trashed_at: Time.now - 1.day)

    RecordingStudioTrashable::SubtreeQuery.stub(:recordings_for, [parent, child]) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, ->(recording:, **) { recording.id == "parent" }) do
        RecordingStudioTrashable.stub(:authorized?, true) do
          result = RecordingStudioTrashable.purge_due_recordings(
            scope_recording: :workspace,
            actor: :system,
            dry_run: true
          )

          assert_empty FakeRecording.destroyed_ids
          assert_empty result.purged_recordings
          assert_equal ["parent"], result.skipped_recordings.map(&:id)
          assert_empty result.would_purge_recordings
        end
      end
    end
  end

  def test_purge_due_recordings_reraises_unrelated_argument_errors
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 10.days)

    parent.define_singleton_method(:recording_studio_trashable_validate_purge!) do |**|
      raise ArgumentError, "boom"
    end

    RecordingStudioTrashable::SubtreeQuery.stub(:recordings_for, [parent]) do
      RecordingStudioTrashable::RetentionPolicy.stub(:due?, true) do
        RecordingStudioTrashable.stub(:authorized?, true) do
          error = assert_raises(ArgumentError) do
            RecordingStudioTrashable.purge_due_recordings(scope_recording: :workspace, actor: :system)
          end

          assert_equal "boom", error.message
        end
      end
    end
  end
end
