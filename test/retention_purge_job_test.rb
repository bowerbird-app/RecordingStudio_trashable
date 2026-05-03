# frozen_string_literal: true

require "test_helper"

class RetentionPurgeJobTest < Minitest::Test
  def test_perform_sweeps_all_root_scopes_with_default_job_metadata
    scope_recordings = %i[root_a root_b]
    captured_arguments = nil
    result = Object.new

    RecordingStudioTrashable.stub(:root_scope_recordings, scope_recordings) do
      RecordingStudioTrashable.stub(:purge_due_recordings_for_all_scopes, lambda { |**kwargs|
        captured_arguments = kwargs
        result
      }) do
        assert_same result, RecordingStudioTrashable::RetentionPurgeJob.perform_now(metadata: { reason: :nightly })
      end
    end

    assert_equal scope_recordings, captured_arguments.fetch(:scope_recordings)
    assert_instance_of Time, captured_arguments.fetch(:as_of)
    assert_equal false, captured_arguments.fetch(:dry_run)
    assert_equal(
      { source: "recording_studio_trashable_retention_job", reason: :nightly },
      captured_arguments.fetch(:metadata)
    )
  end

  def test_perform_uses_requested_scope_recording_ids_when_present
    relation = Object.new
    captured_arguments = nil
    scope_recordings = %i[workspace]
    recording_defined = RecordingStudio.const_defined?(:Recording, false)
    original_recording = RecordingStudio.const_get(:Recording) if recording_defined

    relation.define_singleton_method(:where) do |conditions|
      raise "unexpected conditions" unless conditions == { id: ["scope-1"] }

      self
    end
    relation.define_singleton_method(:reorder) do |*args|
      raise "unexpected order" unless args == [{ created_at: :asc }]

      self
    end
    relation.define_singleton_method(:to_a) { scope_recordings }

    RecordingStudio.const_set(:Recording, Class.new) unless recording_defined
    RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_including_trashed) { relation }

    RecordingStudioTrashable.stub(:purge_due_recordings_for_all_scopes, lambda { |**kwargs|
      captured_arguments = kwargs
      :ok
    }) do
      result = RecordingStudioTrashable::RetentionPurgeJob.perform_now(
        scope_recording_ids: ["scope-1"],
        as_of: Time.utc(2026, 1, 3),
        metadata: { source: :custom }
      )

      assert_equal :ok, result
    end

    assert_equal scope_recordings, captured_arguments.fetch(:scope_recordings)
    assert_equal Time.utc(2026, 1, 3), captured_arguments.fetch(:as_of)
    assert_equal false, captured_arguments.fetch(:dry_run)
    assert_equal({ source: :custom }, captured_arguments.fetch(:metadata))
  ensure
    if recording_defined
      RecordingStudio.const_set(:Recording, original_recording)
    elsif RecordingStudio.const_defined?(:Recording, false)
      RecordingStudio.send(:remove_const, :Recording)
    end
  end

  def test_perform_passes_dry_run_to_sweep
    captured_arguments = nil

    RecordingStudioTrashable.stub(:root_scope_recordings, [:root]) do
      RecordingStudioTrashable.stub(:purge_due_recordings_for_all_scopes, lambda { |**kwargs|
        captured_arguments = kwargs
        :ok
      }) do
        assert_equal :ok, RecordingStudioTrashable::RetentionPurgeJob.perform_now(dry_run: true)
      end
    end

    assert_equal true, captured_arguments.fetch(:dry_run)
  end
end
