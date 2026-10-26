== Recording Studio Trashable installed ==

Next steps:

1. Review config/initializers/recording_studio_trashable.rb
   (requires Recording Studio 6.1.0+ and Flatpack 0.1.315+)
2. Run bin/rails generate recording_studio_trashable:migrations
3. Run bin/rails db:migrate
4. Opt recordables in explicitly with:

   include RecordingStudio::Capabilities::Trashable.to

5. Optionally hide trashed recordings by default in your host app:

    Rails.application.config.to_prepare do
       RecordingStudio::Recording.class_eval do
          default_scope { where(trashed_at: nil) }

          scope :not_trashed, -> { recording_studio_trashable_active }
          scope :with_trashed, -> { recording_studio_trashable_including_trashed }
       end
   end

6. Mount path: <%= options[:mount_path] %>

Mounted trash screens use Recording Studio core's default layout
(back/close page nav and one page title). Call recording_studio_layout on
host controllers that should match, and do not wrap these screens in a
custom sidebar shell. Set RecordingStudioTrashable.configuration.layout
when this addon should use a different layout than the host default.
