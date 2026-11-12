# frozen_string_literal: true

require "rake"
require_relative "../test_helper"

class RetentionPurgeAtTest < ActionDispatch::IntegrationTest
  cattr_accessor :purged_recording_ids

  RecordingStudio::Event.after_create do
    next unless action == "purged" && RetentionPurgeAtTest.purged_recording_ids

    RetentionPurgeAtTest.purged_recording_ids << recording_id
  end

  setup do
    @config = RecordingStudioTrashable.configuration
    @original_allow = @config.allow_user_retention_settings
    @original_default = @config.default_purge_after_days
    @original_resolver = @config.authorization_resolver
    @original_page_options = RecordingStudio.capability_options(:trashable, for_type: "Page")
    @config.allow_user_retention_settings = true
    @config.default_purge_after_days = 30
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    Current.actor = @user
    self.class.purged_recording_ids = nil
  end

  teardown do
    @config.allow_user_retention_settings = @original_allow
    @config.default_purge_after_days = @original_default
    @config.authorization_resolver = @original_resolver
    restore_page_options(@original_page_options)
    self.class.purged_recording_ids = nil
  end

  test "trash stamps purge_at from own setting, ancestor, capability, default, and blank" do
    root = workspace_root("Stamp")
    own = record_page(root, "Own")
    ancestor = record_page(root, "Ancestor")
    blank = record_page(root, "Blank")
    cascade_parent = record_page(root, "Cascade parent")
    cascade_child = record_page(cascade_parent, "Cascade child")
    save_setting(root, 6)
    save_setting(own, 2)
    save_setting(blank, nil)
    save_setting(cascade_child, 2)

    own.recording_studio_trashable_trash!(actor: @user)
    ancestor.recording_studio_trashable_trash!(actor: @user)
    blank.recording_studio_trashable_trash!(actor: @user)
    cascade_parent.recording_studio_trashable_trash!(actor: @user)

    assert_deadline fetch(own), 2
    assert_deadline fetch(ancestor), 6
    assert_nil fetch(blank).purge_at
    assert_deadline fetch(cascade_parent), 6
    child = fetch(cascade_child)
    refute child.trash_root
    assert_deadline child, 2
    assert fetch(cascade_parent).trash_root

    capability = record_page(root, "Capability")
    fallback = record_page(root, "Default")
    with_retention(allow_user: false, default_days: 9, page_days: 14) do
      capability.recording_studio_trashable_trash!(actor: @user)
      assert_deadline fetch(capability), 14
    end
    with_retention(allow_user: false, default_days: 9, page_days: nil) do
      fallback.recording_studio_trashable_trash!(actor: @user)
      assert_deadline fetch(fallback), 9
    end
  end

  test "restore clears purge_at and leaves a nested trash root dated" do
    root = workspace_root("Restore")
    parent = record_page(root, "Restore parent")
    child = record_page(parent, "Restore child")
    nested = record_page(child, "Nested root")
    nested_child = record_page(nested, "Nested child")
    save_setting(root, 4)

    nested.recording_studio_trashable_trash!(actor: @user)
    nested_deadline = fetch(nested).purge_at
    nested_child_deadline = fetch(nested_child).purge_at
    parent.recording_studio_trashable_trash!(actor: @user)
    parent.recording_studio_trashable_restore!(actor: @user)

    assert_nil fetch(parent).trashed_at
    assert_nil fetch(parent).purge_at
    assert_nil fetch(child).trashed_at
    assert_nil fetch(child).purge_at
    assert fetch(nested).trash_root
    assert fetch(nested).trashed_at
    assert_in_delta nested_deadline.to_f, fetch(nested).purge_at.to_f, 1
    assert fetch(nested_child).trashed_at
    refute fetch(nested_child).trash_root
    assert_in_delta nested_child_deadline.to_f, fetch(nested_child).purge_at.to_f, 1
  end

  test "saving or deleting a retention setting restamps the trashed subtree" do
    root = workspace_root("Restamp setting")
    inherited = record_page(root, "Inherited")
    own = record_page(root, "Own child")
    live = record_page(root, "Still live")
    root_setting = save_setting(root, 10)
    save_setting(own, 2)
    inherited.recording_studio_trashable_trash!(actor: @user)
    own.recording_studio_trashable_trash!(actor: @user)

    root_setting.update!(purge_after_days: 4)

    assert_deadline fetch(inherited), 4
    assert_deadline fetch(own), 2
    assert_nil fetch(live).purge_at
    assert_nil fetch(live).trashed_at

    root_setting.destroy!

    assert_deadline fetch(inherited), 30
    assert_deadline fetch(own), 2
    assert_nil fetch(live).purge_at
  end

  test "restamp task backfills null purge_at and is idempotent" do
    root = workspace_root("Backfill")
    page = record_page(root, "Unstamped")
    save_setting(root, 8)
    page.recording_studio_trashable_trash!(actor: @user)
    fetch(page).update_columns(purge_at: nil, trashed_at: 40.days.ago, updated_at: Time.current)

    output = invoke_task("recording_studio_trashable:restamp_purge_at", "SCOPE_RECORDING_IDS" => root.id)
    stamped = fetch(page)
    assert_deadline stamped, 8
    assert_includes output, "Restamped purge_at on"

    again = invoke_task("recording_studio_trashable:restamp_purge_at", "SCOPE_RECORDING_IDS" => root.id)
    assert_equal stamped.purge_at, fetch(page).purge_at
    assert_includes again, "Restamped purge_at on"
  end

  test "purge selects only trashed due rows, leaf first, and honors dry run, scope, and auth" do
    root = workspace_root("Purge")
    other = workspace_root("Other purge")
    parent = record_page(root, "Due parent")
    child = record_page(parent, "Due child")
    live = record_page(root, "Live sibling")
    fresh = record_page(root, "Fresh trash")
    blocked_parent = record_page(root, "Blocked parent")
    blocked_child = record_page(blocked_parent, "Blocked child")
    outside = record_page(other, "Outside")
    save_setting(root, 10)
    save_setting(other, 10)

    parent.recording_studio_trashable_trash!(actor: @user)
    fresh.recording_studio_trashable_trash!(actor: @user)
    blocked_parent.recording_studio_trashable_trash!(actor: @user)
    outside.recording_studio_trashable_trash!(actor: @user)
    age(parent, 40.days.ago)
    age(child, 20.days.ago)
    age(fresh, 1.day.ago)
    age(blocked_parent, 40.days.ago)
    age(outside, 40.days.ago)
    fetch(blocked_child).update_columns(trashed_at: nil, trash_root: false, purge_at: nil, updated_at: Time.current)

    as_of = Time.current
    self.class.purged_recording_ids = []
    preview = purge(root, as_of: as_of, dry_run: true)

    assert_equal [child.id, parent.id], preview.would_purge_recordings.map(&:id)
    assert_equal [blocked_parent.id], preview.skipped_recordings.map(&:id)
    assert_empty preview.purged_recordings
    assert_empty self.class.purged_recording_ids
    assert fetch(parent).trashed_at
    assert_nil fetch(live).purge_at

    denied = @config.authorization_resolver
    @config.authorization_resolver = ->(action:, **) { action.to_sym != :purge }
    error = assert_raises(ArgumentError) { purge(root, as_of: as_of, actor: @user) }
    assert_match(/Not authorized to purge/, error.message)
    assert fetch(child).trashed_at
    @config.authorization_resolver = denied

    result = purge(root, as_of: as_of, actor: @user)
    assert_equal [child.id, parent.id], result.purged_recordings.map(&:id)
    assert_equal [child.id, parent.id], self.class.purged_recording_ids
    assert_equal [blocked_parent.id], result.skipped_recordings.map(&:id)
    assert_nil recording_or_nil(child)
    assert_nil recording_or_nil(parent)
    assert fetch(fresh).trashed_at
    assert fetch(blocked_parent).trashed_at
    assert_nil fetch(live).trashed_at
    assert fetch(outside).trashed_at
    assert_nil fetch(blocked_child).trashed_at
  end

  test "a null purge_at is not purged until restamp" do
    root = workspace_root("Legacy")
    page = record_page(root, "Legacy trash")
    save_setting(root, 3)
    page.recording_studio_trashable_trash!(actor: @user)
    fetch(page).update_columns(purge_at: nil, trashed_at: 40.days.ago, updated_at: Time.current)

    preview = purge(root, as_of: Time.current, dry_run: true)
    assert_empty preview.would_purge_recordings
    assert fetch(page).trashed_at

    RecordingStudioTrashable::PurgeStamp.restamp_subtree!(root)
    result = purge(root, as_of: Time.current, actor: @user)
    assert_equal [page.id], result.purged_recordings.map(&:id)
    assert_nil recording_or_nil(page)
  end

  test "purge selection matches RetentionPolicy.due? for a mixed tree" do
    root = workspace_root("Equivalence")
    other = workspace_root("Equivalence other")
    inherited = record_page(root, "Inherited due")
    own = record_page(root, "Own due")
    blank = record_page(root, "Blank")
    fresh = record_page(root, "Not yet")
    live = record_page(root, "Live")
    parent = record_page(root, "Parent with live child")
    live_child = record_page(parent, "Live child")
    waiting_parent = record_page(root, "Parent waiting")
    waiting_child = record_page(waiting_parent, "Waiting child")
    outside = record_page(other, "Outside due")
    save_setting(root, 10)
    save_setting(own, 2)
    save_setting(blank, nil)
    save_setting(other, 10)

    [inherited, own, blank, fresh, parent, waiting_parent, outside].each do |recording|
      recording.recording_studio_trashable_trash!(actor: @user)
    end
    age(inherited, 40.days.ago)
    age(own, 40.days.ago)
    age(blank, 40.days.ago)
    age(fresh, 1.day.ago)
    age(parent, 40.days.ago)
    age(waiting_parent, 40.days.ago)
    age(waiting_child, 1.day.ago)
    age(outside, 40.days.ago)

    as_of = Time.current
    recordings = RecordingStudioTrashable::SubtreeQuery.recordings_for(root)
    due_ids = due_ids_for(root, recordings, as_of)
    expected_purge = fully_due_ids(recordings, due_ids).sort
    expected_skip = (due_ids - expected_purge).sort

    preview = purge(root, as_of: as_of, dry_run: true)
    assert_equal due_ids.sort, (preview.would_purge_recordings + preview.skipped_recordings).map(&:id).sort
    assert_equal expected_purge, preview.would_purge_recordings.map(&:id).sort
    assert_equal expected_skip, preview.skipped_recordings.map(&:id).sort
    refute_includes preview.would_purge_recordings.map(&:id), live.id
    refute_includes preview.would_purge_recordings.map(&:id), live_child.id
    refute_includes preview.would_purge_recordings.map(&:id), outside.id
    assert_includes expected_purge, inherited.id
    assert_includes expected_purge, own.id
    refute_includes due_ids, blank.id
    refute_includes due_ids, fresh.id
    assert_includes expected_skip, parent.id
    assert_includes expected_skip, waiting_parent.id
  end

  test "job and purge_due task delete due rows in the scope" do
    root = workspace_root("Job")
    page = record_page(root, "Job page")
    save_setting(root, 5)
    page.recording_studio_trashable_trash!(actor: @user)
    age(page, 30.days.ago)
    User.find_by(email: "system@example.com") ||
      User.create!(email: "system@example.com", password: "Password", password_confirmation: "Password")

    RecordingStudioTrashable::RetentionPurgeJob.perform_now(scope_recording_ids: [root.id], as_of: Time.current)
    assert_nil recording_or_nil(page)

    rake_page = record_page(root, "Rake page")
    rake_page.recording_studio_trashable_trash!(actor: @user)
    age(rake_page, 30.days.ago)
    invoke_task(
      "recording_studio_trashable:purge_due",
      "SCOPE_RECORDING_IDS" => root.id,
      "AS_OF" => Time.current.iso8601
    )
    assert_nil recording_or_nil(rake_page)
  end

  test "due purge index is the partial purge_at index" do
    index = RecordingStudio::Recording.connection.indexes(:recording_studio_recordings)
                                      .find { |entry| entry.name == "idx_rs_recordings_due_purge_at" }

    assert index
    assert_equal ["purge_at"], index.columns
    assert_match(/trashed_at IS NOT NULL/i, index.where.to_s)
  end

  private

  def workspace_root(name)
    workspace = Workspace.create!(name: "#{name} #{SecureRandom.hex(4)}")
    RecordingStudio.root_recording_for(workspace)
  end

  def record_page(parent, title)
    parent.record(Page, actor: @user, parent_recording: parent) do |page|
      page.title = title
      page.slug = "#{title.parameterize}-#{SecureRandom.hex(4)}"
    end
  end

  def save_setting(recording, days)
    RecordingStudioTrashable::RetentionSetting.create!(recording: recording, purge_after_days: days)
  end

  def fetch(recording)
    RecordingStudio::Recording.recording_studio_trashable_including_trashed.find(recording.id)
  end

  def recording_or_nil(recording)
    RecordingStudio::Recording.recording_studio_trashable_including_trashed.find_by(id: recording.id)
  end

  def age(recording, trashed_at)
    row = fetch(recording)
    row.update_columns(trashed_at: trashed_at, updated_at: Time.current)
    RecordingStudioTrashable::PurgeStamp.restamp_subtree!(row)
    fetch(recording)
  end

  def purge(scope, as_of:, actor: @user, dry_run: false)
    RecordingStudioTrashable.purge_due_recordings(
      scope_recording: scope,
      actor: actor,
      as_of: as_of,
      dry_run: dry_run
    )
  end

  def assert_deadline(recording, days)
    assert recording.trashed_at
    assert_in_delta (recording.trashed_at + days.days).to_f, recording.purge_at.to_f, 1
  end

  def with_retention(allow_user:, default_days:, page_days:)
    @config.allow_user_retention_settings = allow_user
    @config.default_purge_after_days = default_days
    if page_days.nil?
      RecordingStudio.set_capability_options(:trashable, on: "Page")
    else
      RecordingStudio.set_capability_options(:trashable, on: "Page", purge_after_days: page_days)
    end
    yield
  ensure
    @config.allow_user_retention_settings = true
    @config.default_purge_after_days = 30
    restore_page_options(@original_page_options)
  end

  def restore_page_options(options)
    if options.present?
      RecordingStudio.set_capability_options(:trashable, on: "Page", **options.symbolize_keys)
    else
      RecordingStudio.set_capability_options(:trashable, on: "Page")
    end
  end

  def due_ids_for(scope, recordings, as_of)
    index = recordings.index_by(&:id)
    settings = RecordingStudioTrashable::RetentionPolicy.settings_by_recording_id(recordings)
    recordings.select { |recording|
      RecordingStudioTrashable::RetentionPolicy.due?(
        recording: recording,
        scope_recording: scope,
        as_of: as_of,
        recordings_by_id: index,
        settings_by_recording_id: settings
      )
    }.map(&:id)
  end

  def fully_due_ids(recordings, due_ids)
    children = recordings.group_by(&:parent_recording_id)
    due_set = due_ids.to_set
    recordings.select { |recording|
      due_set.include?(recording.id) && subtree_nodes(recording, children).all? { |node| due_set.include?(node.id) }
    }.map(&:id)
  end

  def subtree_nodes(recording, children)
    nodes = [recording]
    frontier = [recording.id]
    until frontier.empty?
      next_nodes = frontier.flat_map { |parent_id| children.fetch(parent_id, []) }
      nodes.concat(next_nodes)
      frontier = next_nodes.map(&:id)
    end
    nodes
  end

  def invoke_task(name, env)
    Rails.application.load_tasks unless Rake::Task.task_defined?(name)
    previous = env.keys.to_h { |key| [key, ENV[key]] }
    env.each { |key, value| ENV[key] = value }
    task = Rake::Task[name]
    task.reenable
    capture_io { task.invoke }.first
  ensure
    previous&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
