# frozen_string_literal: true

require "test_helper"

class SiblingTrashedAtApiTest < Minitest::Test
  class FakeConnection
    def quote_table_name(name)
      %("#{name}")
    end

    def quote_column_name(name)
      %("#{name}")
    end
  end

  class ScopedRecording
    class << self
      def table_name
        "recording_studio_recordings"
      end

      def connection
        @connection ||= FakeConnection.new
      end

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

  def test_kept_and_trashed_sql_fragments_quote_table_or_alias
    assert_equal '"recording_studio_recordings"."trashed_at" IS NULL',
                 ScopedRecording.recording_studio_trashable_kept_sql
    assert_equal '"child"."trashed_at" IS NULL',
                 ScopedRecording.recording_studio_trashable_kept_sql("child")
    assert_equal '"recording_studio_recordings"."trashed_at" IS NOT NULL',
                 ScopedRecording.recording_studio_trashable_trashed_sql
    assert_equal '"child"."trashed_at" IS NOT NULL',
                 ScopedRecording.recording_studio_trashable_trashed_sql("child")
  end

  def test_sql_helpers_quote_schema_qualified_identifiers_with_one_dot
    assert_equal '"public"."recording_studio_recordings"."trashed_at" IS NULL',
                 ScopedRecording.recording_studio_trashable_kept_sql("public.recording_studio_recordings")
    assert_equal '"public"."recording_studio_recordings"."trashed_at" IS NOT NULL',
                 ScopedRecording.recording_studio_trashable_trashed_sql("public.recording_studio_recordings")
  end

  def test_sql_helpers_reject_nil_and_invalid_identifiers
    error = assert_raises(ArgumentError) { ScopedRecording.recording_studio_trashable_kept_sql(nil) }
    assert_equal "table is required", error.message

    error = assert_raises(ArgumentError) { ScopedRecording.recording_studio_trashable_trashed_sql(nil) }
    assert_equal "table is required", error.message

    error = assert_raises(ArgumentError) { ScopedRecording.recording_studio_trashable_kept_sql("child; drop") }
    assert_includes error.message, "invalid table"

    error = assert_raises(ArgumentError) do
      ScopedRecording.recording_studio_trashable_kept_sql("a.b.c")
    end
    assert_includes error.message, "invalid table"

    error = assert_raises(ArgumentError) do
      ScopedRecording.recording_studio_trashable_kept_sql("public.bad-name")
    end
    assert_includes error.message, "invalid table"
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
    refute_includes method_source, "update!("
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
    assert_includes readme, 'spec.add_dependency "recording_studio_trashable", "~> 0.10"'
    assert_includes readme, 'require "recording_studio_trashable/query"'
    assert_includes readme, "column-existence"
    assert_includes readme, "recording_studio_trashable_active"
    assert_includes readme, "recording_studio_trashable_kept?"
    assert_includes readme, "recording_studio_trashable_trashed?"
    assert_includes readme, "recording_studio_trashable_kept_sql"
    assert_includes readme, "RecordingStudioTrashable.void_recording!"
    assert_includes readme, "update_columns"
    assert_includes readme, "void_oauth_authorization"
    assert_includes readme, "accessible_recording_scope"
    assert_includes readme, "support_section"
    assert_includes readme, "facts_section"
    assert_includes readme, "quote_section"
    assert_includes readme, "credits.rb"
    assert_includes readme, "section_recording_resolver"
    assert_includes readme, "oauth_clients_controller"
    assert_includes readme, "unscoped.recording_studio_trashable_active"
    assert_includes readme, "drops earlier"
    assert_includes readme, "unqualified `trashed_at IS NULL`"
    assert_includes readme, "lowercase"
    assert_includes readme, "case-sensitive"
    assert_includes readme, "api_access_clients_query"
    assert_includes readme, "quote_order"
    assert_includes readme, "quote_images_controller"
    assert_includes readme, "pages/lookups"
    assert_includes readme, "**(conditional)** | When Trashable is loaded: `RecordingStudioTrashable.void_recording!"
  end
end
