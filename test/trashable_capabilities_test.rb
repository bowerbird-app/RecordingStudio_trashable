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

    def lock
      FakeRecording.lock_proxy ||= FakeLock.new(@records.index_by(&:id))
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
        record = records.fetch(id)
        raise KeyError, "missing active record #{id}" if record.trashed_at.present?

        record
      end

      def recording_studio_trashable_including_trashed
        FakeRelation.new(records.values)
      end
    end

    attr_accessor :id, :parent_recording_id, :recordable_type, :trashed_at, :trash_root, :destroyed,
                  :logged_events, :updated_with, :reloaded

    def initialize(id:, parent_recording_id: nil, recordable_type: "Page", trashed_at: nil, trash_root: false)
      @id = id
      @parent_recording_id = parent_recording_id
      @recordable_type = recordable_type
      @trashed_at = trashed_at
      @trash_root = trash_root
      @logged_events = []
      self.class.records ||= {}
      self.class.records[id] = self
    end

    def trash_root?
      !!trash_root
    end

    def reload
      self.reloaded = true
      self
    end

    # rubocop:disable Naming/PredicateMethod
    def update!(attributes)
      self.updated_with = attributes
      self.trashed_at = attributes[:trashed_at] if attributes.key?(:trashed_at)
      self.trash_root = attributes[:trash_root] if attributes.key?(:trash_root)
      true
    end
    # rubocop:enable Naming/PredicateMethod

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

  def stub_authorized(value: true, &)
    RecordingStudioTrashable.stub(:authorized?, value, &)
  end

  def test_to_wraps_core_include_for_factory
    source = File.read(File.expand_path("../lib/recording_studio/trashable/capabilities/trashable.rb", __dir__))

    assert_includes source, "RecordingStudio::Capabilities.include_for(:trashable"
    refute_includes source, "def self.build_capability_module"
    refute_includes source, "def self.apply_capability"
    refute_includes source, "RecordingStudio.enable_capability(:trashable"
  end

  def test_to_delegates_to_include_for_with_validated_options
    captured = nil

    RecordingStudio::Capabilities.stub(:include_for, lambda { |name, **options|
      captured = [name, options]
      Module.new
    }) do
      RecordingStudio::Capabilities::Trashable.to("purge_after_days" => 14)
    end

    assert_equal [:trashable, { purge_after_days: 14 }], captured
  end

  def test_trashable_capability_registration_has_source_without_child_recordables
    registration = RecordingStudio.registered_capabilities.fetch(:trashable)

    assert_equal "recording_studio_trashable", registration.fetch(:source)
    assert_empty registration.fetch(:child_recordables)
  end

  def test_query_scopes_are_explicit_and_namespaced
    source = File.read(File.expand_path("../lib/recording_studio/trashable/capabilities/trashable.rb", __dir__))

    assert_includes source, "scope :recording_studio_trashable_active"
    assert_includes source, "scope :recording_studio_trashable_trashed"
    assert_includes source, "scope :recording_studio_trashable_including_trashed"
    assert_includes source, "scope :recording_studio_trashable_trash_roots"
    assert_includes source, "scope :recording_studio_trashable_filter"
    assert_includes source, "scope :recording_studio_trashable_trash_bin"
  end

  def test_filter_scope_dispatches_to_named_scopes_and_rejects_unknown_filters
    scoped_model = Class.new do
      class << self
        def scope(name, body)
          define_singleton_method(name) do |*args|
            instance_exec(*args, &body)
          end
        end
      end

      include RecordingStudioTrashable::RecordingScopes
    end

    scoped_model.define_singleton_method(:recording_studio_trashable_active) { :active_relation }
    scoped_model.define_singleton_method(:recording_studio_trashable_trashed) { :trashed_relation }
    scoped_model.define_singleton_method(:recording_studio_trashable_including_trashed) { :all_relation }

    assert_equal :active_relation, scoped_model.recording_studio_trashable_filter(:active)
    assert_equal :trashed_relation, scoped_model.recording_studio_trashable_filter("trashed")
    assert_equal :all_relation, scoped_model.recording_studio_trashable_filter(:all)

    error = assert_raises(ArgumentError) { scoped_model.recording_studio_trashable_filter(:bogus) }
    assert_includes error.message, "Unknown trash filter"
    assert_includes error.message, "active, trashed, all"
  end

  def test_trash_logs_event_and_marks_recording_trashed
    recording = FakeRecording.new(id: "page-1")

    stub_authorized do
      recording.recording_studio_trashable_trash!(actor: :editor, metadata: { reason: "cleanup" })
    end

    assert recording.trashed_at
    assert recording.trash_root
    assert_equal "trashed", recording.logged_events.first[:action]
    assert_equal({ reason: "cleanup" }, recording.logged_events.first[:metadata])
  end

  def test_trash_cascades_to_children_when_called
    parent = FakeRecording.new(id: "parent")
    child = FakeRecording.new(id: "child", parent_recording_id: "parent")

    stub_authorized do
      parent.recording_studio_trashable_trash!(actor: :editor)
    end

    assert parent.trashed_at
    assert child.trashed_at
    assert parent.trash_root
    refute child.trash_root
  end

  def test_trashing_parent_preserves_existing_child_trash_root
    parent = FakeRecording.new(id: "parent")
    child = FakeRecording.new(id: "child", parent_recording_id: "parent")

    stub_authorized do
      child.recording_studio_trashable_trash!(actor: :editor)
      parent.recording_studio_trashable_trash!(actor: :editor)
    end

    assert parent.trashed_at
    assert parent.trash_root
    assert child.trashed_at
    assert child.trash_root
  end

  def test_restore_cascades_to_children
    parent = FakeRecording.new(id: "parent")
    child = FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 1.day)
    parent.trashed_at = Time.now - 1.day
    parent.trash_root = true

    stub_authorized do
      parent.recording_studio_trashable_restore!(actor: :editor)
    end

    assert_nil parent.trashed_at
    assert_nil child.trashed_at
    refute parent.trash_root
    refute child.trash_root
    assert_equal "restored", child.logged_events.last[:action]
    assert_equal "restored", parent.logged_events.last[:action]
    assert_equal %w[child parent], FakeRecording.lock_proxy.looked_up_ids.sort
  end

  def test_restore_stops_at_nested_trash_root
    parent = FakeRecording.new(id: "parent")
    child = FakeRecording.new(id: "child", parent_recording_id: "parent")
    nested_root = FakeRecording.new(id: "nested-root", parent_recording_id: "child")
    nested_descendant = FakeRecording.new(id: "nested-descendant", parent_recording_id: "nested-root")

    stub_authorized do
      nested_root.recording_studio_trashable_trash!(actor: :editor)
      parent.recording_studio_trashable_trash!(actor: :editor)
      parent.recording_studio_trashable_restore!(actor: :editor)
    end

    assert_nil parent.trashed_at
    assert_nil child.trashed_at
    assert nested_root.trashed_at
    assert nested_root.trash_root
    assert nested_descendant.trashed_at
    refute nested_descendant.trash_root
  end

  def test_purge_requires_all_descendants_to_already_be_trashed
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 1.day)
    FakeRecording.new(id: "child", parent_recording_id: "parent")

    error = assert_raises(RecordingStudioTrashable::PurgeTargetsNotTrashedError) do
      stub_authorized { parent.recording_studio_trashable_purge!(actor: :admin) }
    end

    assert_equal "Purging requires all targeted recordings to already be trashed", error.message
  end

  def test_purge_logs_purged_and_destroys_descendants_first
    parent = FakeRecording.new(id: "parent", trashed_at: Time.now - 1.day)
    child = FakeRecording.new(id: "child", parent_recording_id: "parent", trashed_at: Time.now - 1.day)

    stub_authorized do
      parent.recording_studio_trashable_purge!(actor: :admin)
    end

    assert child.destroyed
    assert parent.destroyed
    assert_equal "purged", child.logged_events.first[:action]
    assert_equal "purged", parent.logged_events.first[:action]
  end

  def test_purge_requires_targets_to_already_be_trashed
    recording = FakeRecording.new(id: "page-1")

    error = assert_raises(RecordingStudioTrashable::PurgeTargetsNotTrashedError) do
      stub_authorized { recording.recording_studio_trashable_purge!(actor: :admin) }
    end

    assert_equal "Purging requires all targeted recordings to already be trashed", error.message
  end

  def test_lifecycle_raises_when_not_authorized
    recording = FakeRecording.new(id: "page-1")

    error = assert_raises(ArgumentError) do
      stub_authorized(value: false) { recording.recording_studio_trashable_trash!(actor: :viewer) }
    end

    assert_match(/Not authorized to trash/, error.message)
  end
end

class TrashableEnablementFactoryTest < Minitest::Test
  module Probe
    HostPage = Class.new
    HostFolder = Class.new
  end

  def setup
    @original_capabilities =
      RecordingStudio.configuration.instance_variable_get(:@capabilities).transform_values(&:dup)
    @original_capability_options =
      RecordingStudio.configuration.instance_variable_get(:@capability_options).dup
  end

  def teardown
    RecordingStudio.configuration.instance_variable_set(:@capabilities, @original_capabilities)
    RecordingStudio.configuration.instance_variable_set(:@capability_options, @original_capability_options)
  end

  def test_installing_the_gem_registers_trashable_without_enabling_it
    registration = RecordingStudio.registered_capabilities.fetch(:trashable)

    assert_equal "recording_studio_trashable", registration.fetch(:source)
    refute RecordingStudio.capability_enabled?(:trashable, for: Probe::HostPage)
    refute RecordingStudio.capability_enabled?(:trashable, for: Probe::HostFolder)
    refute RecordingStudio.capability_enabled?(:trashable, for: "Page")
    refute RecordingStudio.capability_enabled?(:trashable, for: "Workspace")
    refute RecordingStudio.capability_enabled?(:trashable, for: "Project")
    refute RecordingStudio.capability_enabled?(:trashable, for: "Folder")
  end

  def test_to_enables_trashable_and_sets_options
    Probe::HostPage.include(RecordingStudio::Capabilities::Trashable.to(purge_after_days: 14))

    assert RecordingStudio.capability_enabled?(:trashable, for: Probe::HostPage)
    assert_equal({ purge_after_days: 14 }, RecordingStudio.capability_options(:trashable, for: Probe::HostPage))
    refute RecordingStudio.capability_enabled?(:trashable, for: Probe::HostFolder)
    assert_nil RecordingStudio.capability_options(:trashable, for: Probe::HostFolder)
  end
end
