# frozen_string_literal: true

require_relative "../test_helper"

class SiblingTrashedAtApiIntegrationTest < ActiveSupport::TestCase
  test "Recording exposes kept scope, predicates, SQL helpers, and void" do
    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioTrashable::RecordingScopes
    assert_respond_to RecordingStudio::Recording, :recording_studio_trashable_active
    assert_equal "recording_studio_recordings.trashed_at IS NULL",
                 RecordingStudio::Recording.recording_studio_trashable_kept_sql
    assert_equal "child.trashed_at IS NULL",
                 RecordingStudio::Recording.recording_studio_trashable_kept_sql("child")

    workspace = Workspace.create!(name: "Sibling API workspace #{SecureRandom.hex(4)}")
    recording = RecordingStudio.root_recording_for(workspace)

    assert recording.recording_studio_trashable_kept?
    refute recording.recording_studio_trashable_trashed?

    time = Time.utc(2026, 10, 13, 18, 0, 0)
    RecordingStudioTrashable.void_recording!(recording, time: time)
    recording.reload

    assert recording.recording_studio_trashable_trashed?
    refute recording.recording_studio_trashable_kept?
    assert_in_delta time.to_f, recording.trashed_at.to_f, 1
    assert_equal false, recording.trash_root
    assert_includes RecordingStudio::Recording.recording_studio_trashable_trashed.where(id: recording.id), recording
    assert_empty RecordingStudio::Recording.recording_studio_trashable_active.where(id: recording.id)
  end
end
