== Recording Studio Trashable installed ==

Next steps:

1. Review config/initializers/recording_studio_trashable.rb
   (requires Recording Studio 6.14.0 or newer, below 7.0, and Flatpack 0.1.315+)
2. Run bin/rails generate recording_studio_trashable:migrations
3. Run bin/rails db:migrate
4. Opt recordables in explicitly with:

   include RecordingStudio::Capabilities::Trashable.to

5. Skip trashed rows with RecordingStudio::Recording.kept.
   Joins use RecordingStudio.kept_sql("child"). The engine registers the
   :trashable filter once. Do not register it from to_prepare.
   Until trashed_at exists, kept applies no filter and does not raise.

6. Mount path: <%= options[:mount_path] %>

Mounted trash screens use Recording Studio core's default layout
(back/close page nav and one page title). Call recording_studio_layout on
host controllers that should match, and do not wrap these screens in a
custom sidebar shell. Set RecordingStudioTrashable.configuration.layout
when this addon should use a different layout than the host default.
