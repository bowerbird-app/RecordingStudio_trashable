# frozen_string_literal: true

require "test_helper"

class SiblingTrashedAtApiTest < Minitest::Test
  class ScopedRecording
    class << self
      def scope(name, body)
        define_singleton_method(name) do |*args|
          instance_exec(*args, &body)
        end
      end
    end

    include RecordingStudioTrashable::RecordingScopes

    attr_accessor :trashed_at, :updated_at, :updated_with, :update_bang_called

    def initialize(trashed_at: nil, updated_at: nil)
      @trashed_at = trashed_at
      @updated_at = updated_at
      @update_bang_called = false
    end

    def update!(*)
      @update_bang_called = true
      raise "update! must not be called"
    end

    def update_columns(attributes)
      self.updated_with = attributes
      self.trashed_at = attributes[:trashed_at] if attributes.key?(:trashed_at)
      self.updated_at = attributes[:updated_at] if attributes.key?(:updated_at)
      self
    end
  end

  def test_void_recording_cascades_update_columns_and_skips_rows_already_trashed
    time = Time.utc(2026, 10, 13, 15, 30, 0)
    earlier = Time.utc(2026, 10, 1, 0, 0, 0)
    parent = ScopedRecording.new(trashed_at: nil)
    child = ScopedRecording.new(trashed_at: nil)
    grandchild = ScopedRecording.new(trashed_at: earlier)
    parent.define_singleton_method(:descendants) { [child, grandchild] }

    result = RecordingStudioTrashable.void_recording!(parent, time: time)

    assert_same parent, result
    assert_equal time, parent.trashed_at
    assert_equal({ trashed_at: time, updated_at: time }, parent.updated_with)
    assert_equal time, child.trashed_at
    assert_equal({ trashed_at: time, updated_at: time }, child.updated_with)
    assert_equal earlier, grandchild.trashed_at
    assert_nil grandchild.updated_with
    refute parent.update_bang_called
    refute child.update_bang_called
  end

  def test_trashed_and_kept_predicates
    active = ScopedRecording.new(trashed_at: nil)
    trashed = ScopedRecording.new(trashed_at: Time.utc(2026, 10, 13, 12, 0, 0))

    refute active.recording_studio_trashable_trashed?
    assert active.recording_studio_trashable_kept?
    assert trashed.recording_studio_trashable_trashed?
    refute trashed.recording_studio_trashable_kept?
  end

  def test_void_recording_uses_update_columns_with_trashed_at_and_updated_at
    recording = ScopedRecording.new(trashed_at: nil, updated_at: Time.utc(2026, 1, 1))
    time = Time.utc(2026, 10, 13, 15, 30, 0)

    result = RecordingStudioTrashable.void_recording!(recording, time: time)

    assert_same recording, result
    assert_equal time, recording.trashed_at
    assert_equal time, recording.updated_at
    assert_equal({ trashed_at: time, updated_at: time }, recording.updated_with)
    refute recording.update_bang_called
  end

  def test_void_recording_source_pins_update_columns_not_update_bang
    source = File.read(File.expand_path("../lib/recording_studio_trashable/query.rb", __dir__))
    method_source = source[/def void_recording!\(.*?\n    end/m]

    refute_nil method_source
    assert_includes method_source, "update_columns(trashed_at: time, updated_at: time)"
    assert_includes method_source, "void_targets"
    refute_includes method_source, "update!("
    assert_includes source, "recording.descendants"
  end

  def test_void_recording_is_idempotent_when_already_trashed
    time = Time.utc(2026, 10, 1, 0, 0, 0)
    recording = ScopedRecording.new(trashed_at: time)

    RecordingStudioTrashable.void_recording!(recording, time: Time.utc(2026, 10, 13))

    assert_equal time, recording.trashed_at
    assert_nil recording.updated_with
  end

  def test_void_recording_requires_a_recording
    error = assert_raises(ArgumentError) { RecordingStudioTrashable.void_recording!(nil) }
    assert_equal "recording is required", error.message
  end

  def test_instance_void_delegates_to_module_method
    recording = ScopedRecording.new(trashed_at: nil)
    time = Time.utc(2026, 10, 13, 16, 0, 0)

    recording.recording_studio_trashable_void!(time: time)

    assert_equal time, recording.trashed_at
    assert_equal({ trashed_at: time, updated_at: time }, recording.updated_with)
  end

  def test_readme_maps_sibling_call_sites_to_trashable_api
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "### Sibling gem `trashed_at` mapping"
    assert_includes readme, 'spec.add_dependency "recording_studio_trashable", "~> 0.16"'
    assert_includes readme, 'require "recording_studio_trashable/query"'
    assert_includes readme, "column-existence"
    assert_includes readme, "RecordingStudio::Recording.kept"
    assert_includes readme, "RecordingStudio.kept_sql"
    assert_includes readme, "recording_studio_trashable_kept?"
    assert_includes readme, "recording_studio_trashable_trashed?"
    refute_includes readme, "recording_studio_trashable_active"
    refute_includes readme, "recording_studio_trashable_kept_sql"
    assert_includes readme, "RecordingStudioTrashable.void_recording!"
    assert_includes readme, "update_columns"
    assert_includes readme, "descendants"
    assert_includes readme, "void_oauth_authorization"
    assert_includes readme, "accessible_recording_scope"
    assert_includes readme, "support_section"
    assert_includes readme, "facts_section"
    assert_includes readme, "quote_section"
    assert_includes readme, "credits.rb"
    assert_includes readme, "section_recording_resolver"
    assert_includes readme, "oauth_clients_controller"
    assert_includes readme, "RecordingStudio::Recording.kept.find_by"
    assert_includes readme, "does not unscope"
    assert_includes readme, "unqualified `trashed_at IS NULL`"
    assert_includes readme, "api_access_clients_query"
    assert_includes readme, "quote_order"
    assert_includes readme, "quote_images_controller"
    assert_includes readme, "pages/lookups"
    assert_includes readme, "descendants are voided too"
  end
end
