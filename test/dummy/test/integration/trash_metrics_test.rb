# frozen_string_literal: true

require_relative "../test_helper"

class TrashMetricsTest < ActionDispatch::IntegrationTest
  Grant = Struct.new(:actor)
  ApiContext = Struct.new(:access_grant, :access_recording, :root_recording, :api_client, :params, :api_key)

  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    Current.actor = @user
    @member = User.find_by(email: "member@example.com") ||
              User.create!(email: "member@example.com", password: "Password", password_confirmation: "Password")
    @workspace = Workspace.create!(name: "Metrics Workspace #{SecureRandom.hex(4)}")
    @workspace_recording = RecordingStudio.root_recording_for(@workspace)
    @baseline_in_trash = current_trash.count
    @baseline_by_type = current_trash.group(:recordable_type).count
    @baseline_by_day = current_trash.group("DATE(trashed_at)").count
    seed_recordings
    RecordingStudioTrashable::Metrics.register! unless RecordingStudioMetrics.find("trash.in_trash")
  end

  test "in_trash counts current trash and ignores live recordings" do
    result = execute_metric("trash.in_trash")

    assert_equal @baseline_in_trash + 4, result.value
    assert_operator live_count, :>, 0
  end

  test "in_trash_by_type groups still-existing trash by recordable_type" do
    result = execute_metric("trash.in_trash_by_type")
    counts = result.data.to_h { |row| [row[:key] || row["key"], row[:value] || row["value"]] }

    assert_equal @baseline_by_type.fetch("Project", 0) + 1, counts["Project"]
    assert_equal @baseline_by_type.fetch("Folder", 0) + 1, counts["Folder"]
    assert_equal @baseline_by_type.fetch("Page", 0) + 2, counts["Page"]
    assert_equal @baseline_by_type.fetch("Workspace", 0), counts.fetch("Workspace", 0)
  end

  test "trashed_over_time buckets still-existing items by trashed_at" do
    result = RecordingStudioMetrics.execute(
      "trash.trashed_over_time",
      context: site_context,
      interval: :day,
      start_at: 5.days.ago.beginning_of_day,
      end_at: Time.current.end_of_day
    )
    by_date = result.data.to_h { |row| [row[:date] || row["date"], row[:value] || row["value"]] }

    assert_equal day_baseline(2) + 2, by_date.fetch(2.days.ago.to_date.iso8601)
    assert_equal day_baseline(3) + 1, by_date.fetch(3.days.ago.to_date.iso8601)
    assert_equal day_baseline(1) + 1, by_date.fetch(1.day.ago.to_date.iso8601)
  end

  test "staff can_view and api_authorize grant site context" do
    with_admin_access(authorized: true) do
      grant = Grant.new(@user)
      api_context = ApiContext.new(grant, nil, nil, nil, {}, :operations)
      definition = RecordingStudioMetrics.find("trash.in_trash")

      assert RecordingStudioTrashable::Api::Access.can_view?(api_context)
      context = RecordingStudioMetrics::Api.context_from_api(api_context, definition: definition)
      assert context
      assert_equal :site, context.scope
      assert context.site_authorized?
    end
  end

  test "non-admin is denied by can_view and api_authorize" do
    with_admin_access(authorized: false) do
      grant = Grant.new(@member)
      api_context = ApiContext.new(grant, nil, nil, nil, {}, :operations)
      definition = RecordingStudioMetrics.find("trash.in_trash")

      refute RecordingStudioTrashable::Api::Access.can_view?(api_context)
      assert_nil RecordingStudioMetrics::Api.context_from_api(api_context, definition: definition)
    end
  end

  private

  def seed_recordings
    live_project = record(Project, parent: @workspace_recording) do |project|
      project.name = "Live Project"
      project.slug = "live-project-#{SecureRandom.hex(4)}"
    end
    trashed_project = record(Project, parent: @workspace_recording) do |project|
      project.name = "Trashed Project"
      project.slug = "trashed-project-#{SecureRandom.hex(4)}"
    end
    live_folder = record(Folder, parent: live_project) do |folder|
      folder.name = "Live Folder"
      folder.slug = "live-folder-#{SecureRandom.hex(4)}"
    end
    trashed_folder = record(Folder, parent: live_project) do |folder|
      folder.name = "Trashed Folder"
      folder.slug = "trashed-folder-#{SecureRandom.hex(4)}"
    end
    live_page = record(Page, parent: live_folder) do |page|
      page.title = "Live Page"
      page.slug = "live-page-#{SecureRandom.hex(4)}"
    end
    old_page = record(Page, parent: live_folder) do |page|
      page.title = "Old Trashed Page"
      page.slug = "old-trashed-#{SecureRandom.hex(4)}"
    end
    mid_page = record(Page, parent: live_folder) do |page|
      page.title = "Mid Trashed Page"
      page.slug = "mid-trashed-#{SecureRandom.hex(4)}"
    end

    mark_trashed(trashed_project, 2.days.ago)
    mark_trashed(trashed_folder, 3.days.ago)
    mark_trashed(old_page, 2.days.ago)
    mark_trashed(mid_page, 1.day.ago)
    assert_nil live_page.trashed_at
    assert_nil @workspace_recording.trashed_at
  end

  def record(type, parent:, &block)
    @workspace_recording.record(type, actor: @user, parent_recording: parent, &block)
  end

  def mark_trashed(recording, time)
    recording.update_columns(trashed_at: time, trash_root: true, updated_at: Time.current)
  end

  def current_trash
    RecordingStudio::Recording.unscope(where: :trashed_at).where.not(trashed_at: nil)
  end

  def live_count
    RecordingStudio::Recording.unscope(where: :trashed_at).where(trashed_at: nil).count
  end

  def day_baseline(days_ago)
    date = days_ago.days.ago.to_date
    @baseline_by_day.each do |key, value|
      return value if key.to_s == date.to_s || key.to_s.start_with?(date.iso8601)
    end
    0
  end

  def execute_metric(identifier)
    RecordingStudioMetrics.execute(identifier, context: site_context)
  end

  def site_context
    RecordingStudioMetrics::Context.new(actor: @user, scope: :site, site_authorized: true)
  end

  def with_admin_access(authorized:)
    admin = Module.new do
      def self.configuration
        @configuration
      end
    end
    admin.instance_variable_set(
      :@configuration,
      Struct.new(:access_recording_resolver).new(->(_context) { @workspace_recording })
    )
    accessible = Module.new do
      def self.authorized?(**)
        @authorized
      end
    end
    accessible.instance_variable_set(:@authorized, authorized)

    swap_const(:RecordingStudioAdmin, admin)
    swap_const(:RecordingStudioAccessible, accessible)
    yield
  ensure
    restore_const(:RecordingStudioAdmin)
    restore_const(:RecordingStudioAccessible)
  end

  def swap_const(name, replacement)
    @original_consts ||= {}
    @original_consts[name] = Object.const_defined?(name, false) ? Object.const_get(name, false) : :__missing__
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, replacement)
  end

  def restore_const(name)
    return unless @original_consts&.key?(name)

    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    original = @original_consts.delete(name)
    Object.const_set(name, original) unless original == :__missing__
  end
end
