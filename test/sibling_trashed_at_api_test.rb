# frozen_string_literal: true

require "test_helper"

class SiblingTrashedAtApiTest < Minitest::Test
  class ScopedRecording
    class << self
      def table_name
        "recording_studio_recordings"
      end

      def scope(name, body)
        define_singleton_method(name) do |*args|
          instance_exec(*args, &body)
        end
      end
    end

    include RecordingStudioTrashable::RecordingScopes

    attr_accessor :trashed_at, :updated_with

    def initialize(trashed_at: nil)
      @trashed_at = trashed_at
    end

    def update!(attributes)
      self.updated_with = attributes
      self.trashed_at = attributes[:trashed_at] if attributes.key?(:trashed_at)
      self
    end
  end

  def test_kept_and_trashed_sql_fragments_qualify_table_or_alias
    assert_equal "recording_studio_recordings.trashed_at IS NULL",
                 ScopedRecording.recording_studio_trashable_kept_sql
    assert_equal "child.trashed_at IS NULL",
                 ScopedRecording.recording_studio_trashable_kept_sql("child")
    assert_equal "recording_studio_recordings.trashed_at IS NOT NULL",
                 ScopedRecording.recording_studio_trashable_trashed_sql
    assert_equal "child.trashed_at IS NOT NULL",
                 ScopedRecording.recording_studio_trashable_trashed_sql("child")
  end

  def test_trashed_and_kept_predicates
    active = ScopedRecording.new(trashed_at: nil)
    trashed = ScopedRecording.new(trashed_at: Time.utc(2026, 10, 13, 12, 0, 0))

    refute active.recording_studio_trashable_trashed?
    assert active.recording_studio_trashable_kept?
    assert trashed.recording_studio_trashable_trashed?
    refute trashed.recording_studio_trashable_kept?
  end

  def test_void_recording_sets_trashed_at_through_update_without_trash_root
    recording = ScopedRecording.new(trashed_at: nil)
    time = Time.utc(2026, 10, 13, 15, 30, 0)

    result = RecordingStudioTrashable.void_recording!(recording, time: time)

    assert_same recording, result
    assert_equal time, recording.trashed_at
    assert_equal({ trashed_at: time }, recording.updated_with)
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
    assert_equal({ trashed_at: time }, recording.updated_with)
  end

  def test_readme_maps_sibling_call_sites_to_trashable_api
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "### Sibling gem `trashed_at` mapping"
    assert_includes readme, "recording_studio_trashable_active"
    assert_includes readme, "recording_studio_trashable_kept?"
    assert_includes readme, "recording_studio_trashable_trashed?"
    assert_includes readme, "recording_studio_trashable_kept_sql"
    assert_includes readme, "RecordingStudioTrashable.void_recording!"
    assert_includes readme, "void_oauth_authorization"
    assert_includes readme, "accessible_recording_scope"
    assert_includes readme, "support_section"
    assert_includes readme, "facts_section"
    assert_includes readme, "section_recording_resolver"
  end
end
