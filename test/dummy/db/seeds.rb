user = User.find_or_create_by!(email: "admin@admin.com") do |record|
  record.password = "Password"
  record.password_confirmation = "Password"
end

system_user = User.find_or_create_by!(email: "system@example.com") do |record|
  record.password = "Password"
  record.password_confirmation = "Password"
end

trashed_demo_page_count = 100

Current.actor = user

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
workspace_recording = RecordingStudio.root_recording_for(workspace)

project_recording = DemoRecordingLookup.by_slug(type: "Project", slug: "album-launch")
unless project_recording
  project_recording = workspace_recording.record(Project, actor: user, metadata: { seed: true }, parent_recording: workspace_recording) do |project|
    project.name = "Album Launch"
    project.slug = "album-launch"
  end
end

second_project_recording = DemoRecordingLookup.by_slug(type: "Project", slug: "session-archive")
unless second_project_recording
  second_project_recording = workspace_recording.record(Project, actor: user, metadata: { seed: true }, parent_recording: workspace_recording) do |project|
    project.name = "Session Archive"
    project.slug = "session-archive"
  end
end

folder_recording = DemoRecordingLookup.by_slug(type: "Folder", slug: "reference-assets")
unless folder_recording
  folder_recording = workspace_recording.record(Folder, actor: user, metadata: { seed: true }, parent_recording: project_recording) do |folder|
    folder.name = "Reference Assets"
    folder.slug = "reference-assets"
  end
end

mix_notes_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "mix-notes")
unless mix_notes_recording
  mix_notes_recording = workspace_recording.record(Page, actor: user, metadata: { seed: true }, parent_recording: project_recording) do |page|
    page.title = "Mix Notes"
    page.slug = "mix-notes"
    page.body = "Active page used for the trash flow demo."
  end
end

release_checklist_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "release-checklist")
unless release_checklist_recording
  release_checklist_recording = workspace_recording.record(Page, actor: user, metadata: { seed: true }, parent_recording: second_project_recording) do |page|
    page.title = "Release Checklist"
    page.slug = "release-checklist"
    page.body = "Second active page used to keep the homepage demo table populated."
  end
end

trash_root_parent_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "trash-root-parent")
unless trash_root_parent_recording
  trash_root_parent_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: project_recording
  ) do |page|
    page.title = "Trash Root Parent"
    page.slug = "trash-root-parent"
    page.body = "Directly trashed parent page used to demonstrate trash_root listings."
  end
end

trash_root_child_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "trash-root-child")
unless trash_root_child_recording
  trash_root_child_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: trash_root_parent_recording
  ) do |page|
    page.title = "Trash Root Child"
    page.slug = "trash-root-child"
    page.body = "Cascade-trashed child page used to demonstrate hidden non-root descendants."
  end
end

trash_root_grandchild_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "trash-root-grandchild")
unless trash_root_grandchild_recording
  trash_root_grandchild_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: trash_root_child_recording
  ) do |page|
    page.title = "Trash Root Grandchild"
    page.slug = "trash-root-grandchild"
    page.body = "Cascade-trashed grandchild page used to demonstrate deeper hidden descendants."
  end
end

nested_trash_parent_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "nested-trash-parent")
unless nested_trash_parent_recording
  nested_trash_parent_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: second_project_recording
  ) do |page|
    page.title = "Nested Trash Parent"
    page.slug = "nested-trash-parent"
    page.body = "Parent page used to demonstrate nested explicit trash roots."
  end
end

nested_trash_child_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "nested-trash-child")
unless nested_trash_child_recording
  nested_trash_child_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: nested_trash_parent_recording
  ) do |page|
    page.title = "Nested Trash Child"
    page.slug = "nested-trash-child"
    page.body = "Explicitly trashed child page that remains a trash root after its parent is trashed."
  end
end

nested_trash_grandchild_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "nested-trash-grandchild")
unless nested_trash_grandchild_recording
  nested_trash_grandchild_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: nested_trash_child_recording
  ) do |page|
    page.title = "Nested Trash Grandchild"
    page.slug = "nested-trash-grandchild"
    page.body = "Cascade-trashed descendant beneath a nested explicit trash root."
  end
end

archived_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "archived-lyrics")
unless archived_recording
  archived_recording = workspace_recording.record(Page, actor: user, metadata: { seed: true }, parent_recording: folder_recording) do |page|
    page.title = "Archived Lyrics"
    page.slug = "archived-lyrics"
    page.body = "Trashed page used for restore and purge demos."
  end
  archived_recording.recording_studio_trashable_trash!(actor: user)
end

expired_default_retention_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "expired-default-retention")
unless expired_default_retention_recording
  expired_default_retention_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: second_project_recording
  ) do |page|
    page.title = "Expired Default Retention"
    page.slug = "expired-default-retention"
    page.body = "Seeded trash item that is older than the 30 day default retention period."
  end
end

expired_scope_retention_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "expired-scope-retention")
unless expired_scope_retention_recording
  expired_scope_retention_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: project_recording
  ) do |page|
    page.title = "Expired Scope Retention"
    page.slug = "expired-scope-retention"
    page.body = "Seeded trash item that is older than the project-level 14 day retention period."
  end
end

fresh_retention_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "fresh-retention")
unless fresh_retention_recording
  fresh_retention_recording = workspace_recording.record(
    Page,
    actor: user,
    metadata: { seed: true },
    parent_recording: project_recording
  ) do |page|
    page.title = "Fresh Retention"
    page.slug = "fresh-retention"
    page.body = "Seeded trash item that should remain because it is still inside the retention window."
  end
end

if trash_root_parent_recording.trashed_at.blank?
  trash_root_parent_recording.recording_studio_trashable_trash!(actor: user)
end

if nested_trash_child_recording.trashed_at.blank?
  nested_trash_child_recording.recording_studio_trashable_trash!(actor: user)
end

if nested_trash_parent_recording.trashed_at.blank?
  nested_trash_parent_recording.recording_studio_trashable_trash!(actor: user)
end

if expired_default_retention_recording.trashed_at.blank?
  expired_default_retention_recording.recording_studio_trashable_trash!(actor: user)
end
expired_default_retention_recording.update!(trashed_at: 45.days.ago)

if expired_scope_retention_recording.trashed_at.blank?
  expired_scope_retention_recording.recording_studio_trashable_trash!(actor: user)
end
expired_scope_retention_recording.update!(trashed_at: 21.days.ago)

if fresh_retention_recording.trashed_at.blank?
  fresh_retention_recording.recording_studio_trashable_trash!(actor: user)
end
fresh_retention_recording.update!(trashed_at: 5.days.ago)

trashed_demo_page_count.times do |index|
  slug = format("archived-demo-page-%03d", index + 1)
  trashed_page_recording = DemoRecordingLookup.by_slug(type: "Page", slug: slug)

  unless trashed_page_recording
    trashed_page_recording = workspace_recording.record(Page, actor: user, metadata: { seed: true }, parent_recording: folder_recording) do |page|
      page.title = format("Archived Demo Page %03d", index + 1)
      page.slug = slug
      page.body = format("Seeded trashed page %03d for pagination demos.", index + 1)
    end
  end

  trashed_page_recording.recording_studio_trashable_trash!(actor: user) if trashed_page_recording.trashed_at.blank?
end

retention_setting = RecordingStudioTrashable::RetentionSetting.find_or_initialize_by(recording: project_recording)
retention_setting.update!(purge_after_days: 14)

puts "Seeded: admin@admin.com / Password"
puts "Seeded scheduled purge actor: system@example.com / Password"
puts "Seeded homepage demo rows for 2 projects, 2 active pages, and 2 trashed pages"
puts "Seeded #{trashed_demo_page_count + 1} trash-root pages for trash-bin pagination demos"
puts "Seeded trash_root examples: trash-root-parent (root with hidden descendants), nested-trash-parent and nested-trash-child (nested explicit roots)"
puts "Seeded retention demo pages: expired-default-retention (45 days), expired-scope-retention (21 days), fresh-retention (5 days)"
puts "Seeded workspace trash bin: /recording_studio_trashable/recordings/#{workspace_recording.id}/trash_bin"
puts "Seeded project trash bin: /recording_studio_trashable/recordings/#{project_recording.id}/trash_bin"
