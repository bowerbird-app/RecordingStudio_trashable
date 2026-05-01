# frozen_string_literal: true

require "test_helper"
require "rake"

class RetentionPurgeTaskTest < Minitest::Test
  Result = Struct.new(:purged_recordings, :skipped_recordings, :scope_recordings, keyword_init: true)

  def setup
    @original_rake = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load File.expand_path("../lib/tasks/recording_studio_trashable.rake", __dir__)
  end

  def teardown
    Rake.application = @original_rake
  end

  def test_purge_due_task_invokes_job_with_env_arguments_and_prints_summary
    captured_arguments = nil
    result = Result.new(
      purged_recordings: %i[a b],
      skipped_recordings: [:c],
      scope_recordings: %i[root_a root_b]
    )

    output = with_env(
      "SCOPE_RECORDING_IDS" => "scope-1,scope-2",
      "AS_OF" => "2026-01-04T00:00:00Z",
      "SOURCE" => "nightly"
    ) do
      RecordingStudioTrashable::RetentionPurgeJob.stub(:perform_now, lambda { |**kwargs|
        captured_arguments = kwargs
        result
      }) do
        task = Rake::Task["recording_studio_trashable:purge_due"]
        task.reenable

        capture_io { task.invoke }.first
      end
    end

    assert_equal(
      {
        scope_recording_ids: %w[scope-1 scope-2],
        as_of: Time.utc(2026, 1, 4),
        metadata: { source: "nightly" }
      },
      captured_arguments
    )
    assert_includes output, "Purged 2 recordings, skipped 1 across 2 scopes"
  end

  private

  def with_env(overrides)
    original = overrides.transform_values { nil }
    overrides.each_key { |key| original[key] = ENV.fetch(key, nil) }
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
