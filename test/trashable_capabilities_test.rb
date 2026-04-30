# frozen_string_literal: true

require "test_helper"

class TrashableCapabilitiesTest < Minitest::Test
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

    def to_a
      @records
    end
  end

  class FakeLock
    attr_reader :looked_up_ids

    def initialize(records)
      @records = records
      @looked_up_ids = []
    end

    def find(id)
      looked_up_ids << id
      @records.fetch(id)
    end
  end

  class FakeRecording
    include RecordingStudio::Trashable::Capabilities::Trashable::RecordingMethods

    class << self
      attr_accessor :records, :lock_proxy

      def transaction
        yield
      end

      def lock
        self.lock_proxy ||= FakeLock.new(records)
      end

      def find(id)
        records.fetch(id)
      end

      def recording_studio_trashable_including_trashed
        FakeRelation.new(records.values)
      end
    end

    attr_accessor :id, :parent_recording_id, :recordable_type, :trashed_at, :destroyed,
                  :logged_events, :updated_with, :reloaded

    def initialize(id:, parent_recording_id: nil, recordable_type: "Page", trashed_at: nil)
      @id = id
      @parent_recording_id = parent_recording_id
      @recordable_type = recordable_type
      @trashed_at = trashed_at
      @logged_events = []
      self.class.records ||= {}
      self.class.records[id] = self
    end

    def reload
      self.reloaded = true
      self
    end

    def update!(attributes)
      self.updated_with = attributes
      self.trashed_at = attributes[:trashed_at] if attributes.key?(:trashed_at)
      true
    end

    def destroy!
      self.destroyed = true
      self.class.records.delete(id)
    end

    def log_event!(**attributes)
      logged_events << attributes
    end

    def assert_capability!(capability)
      raise "unexpected capability" unless capability == :trashable
    end
  end

  def setup
    FakeRecording.records = {}
    FakeRecording.lock_proxy = nil
    @original_authorized = RecordingStudioTrashable.method(:authorized?)
  end

  def teardown
    FakeRecording.records = {}
    FakeRecording.lock_proxy = nil
  end

  def stub_authorized(value = true, &block)
    RecordingStudioTrashable.stub(:authorized?, value, &block)
  end

  def test_capability_builder_registers_capability_options
    applied = []
    base = Struct.new(:name).new("Page")

    RecordingStudio.stub(:enable_capability, ->(*args, **kwargs) { applied << [:enable, args, kwargs] }) do
      RecordingStudio.stub(:set_capability_options, ->(*args, **kwargs) { applied << [:options, args, kwargs] }) do
        RecordingStudio::Trashable::Capabilities::Trashable.apply_capability(base, cascade: true)
      end
    end

    assert_equal [:enable, [:trashable], { on: "Page" }], applied.first
    assert_equal [:options, [:trashable], { on: "Page", cascade: true }], applied.last
  end

  def test_query_scopes_are_explicit_and_namespaced
    source = File.read(File.expand_path("../lib/recording_studio/trashable/capabilities/trashable.rb", __dir__))

    assert_includes source, "scope :recording_studio_trashable_active"
    assert_includes source, "scope :recording_studio_trashable_trashed"
    assert_includes source, "scope :recording_studio_trashable_including_trashed"
    assert_includes source, "scope :recording_studio_trashable_trash_bin"
  end

  def test_trash_logs_event_and_marks_recording_trashed
    recording = FakeRecording.new(id: "page-1")

    stub_authorized do
      recording.recording_studio_trashable_trash!(actor: :editor, metadata: { reason: "cleanup" })
    end

    assert recording.trashed_at
    assert_equal "trashed", recording.logged_events.first[:action]
    assert_equal({ reason: "cleanup", include_children: false }, recording.logged_events.first[:metadata])
  end

  def test_restore_cascades_to_children_when_requested
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 1.day)
    child = FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 1.day)

    stub_authorized do
      parent.recording_studio_trashable_restore!(actor: :editor, include_children: true)
    end

    assert_nil parent.trashed_at
    assert_nil child.trashed_at
    assert_equal %w[child parent], FakeRecording.lock_proxy.looked_up_ids.sort
  end

  def test_purge_requires_include_children_when_descendants_exist
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 1.day)
    FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 1.day)

    error = assert_raises(ArgumentError) do
      stub_authorized { parent.recording_studio_trashable_purge!(actor: :admin) }
    end

    assert_equal "Purging a recording with descendants requires include_children: true", error.message
  end

  def test_purge_logs_purged_and_destroys_descendants_first
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 1.day)
    child = FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 1.day)

    stub_authorized do
      parent.recording_studio_trashable_purge!(actor: :admin, include_children: true)
    end

    assert child.destroyed
    assert parent.destroyed
    assert_equal "purged", child.logged_events.first[:action]
    assert_equal "purged", parent.logged_events.first[:action]
  end

  def test_lifecycle_raises_when_not_authorized
    recording = FakeRecording.new(id: "page-1")

    error = assert_raises(ArgumentError) do
      stub_authorized(false) { recording.recording_studio_trashable_trash!(actor: :viewer) }
    end

    assert_match(/Not authorized to trash/, error.message)
  end
end
