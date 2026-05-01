user = User.find_or_create_by!(email: "admin@admin.com") do |record|
  record.password = "Password"
  record.password_confirmation = "Password"
end

trashed_demo_page_count = 100

Current.actor = user

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
workspace_recording = RecordingStudio::Recording.recording_studio_trashable_including_trashed.find_or_create_by!(
  recordable: workspace,
  parent_recording_id: nil
)

access = RecordingStudio::Access.find_or_create_by!(actor: user, role: :admin)
RecordingStudio::Recording.recording_studio_trashable_including_trashed.find_or_create_by!(
  root_recording_id: workspace_recording.id,
  parent_recording_id: workspace_recording.id,
  recordable: access
)

project_recording = DemoRecordingLookup.by_slug(type: "Project", slug: "album-launch")
unless project_recording
  project_recording = workspace_recording.record(Project, actor: user, metadata: { seed: true }, parent_recording: workspace_recording) do |project|
    project.name = "Album Launch"
    project.slug = "album-launch"
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

archived_recording = DemoRecordingLookup.by_slug(type: "Page", slug: "archived-lyrics")
unless archived_recording
  archived_recording = workspace_recording.record(Page, actor: user, metadata: { seed: true }, parent_recording: folder_recording) do |page|
    page.title = "Archived Lyrics"
    page.slug = "archived-lyrics"
    page.body = "Trashed page used for restore and purge demos."
  end
  archived_recording.recording_studio_trashable_trash!(actor: user)
end

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
puts "Seeded #{trashed_demo_page_count + 1} trashed pages for trash-bin pagination demos"
puts "Seeded workspace trash bin: /recording_studio_trashable/recordings/#{workspace_recording.id}/trash_bin"
puts "Seeded project trash bin: /recording_studio_trashable/recordings/#{project_recording.id}/trash_bin"
