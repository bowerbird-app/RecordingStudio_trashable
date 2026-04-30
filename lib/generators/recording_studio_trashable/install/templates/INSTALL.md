== Recording Studio Trashable installed ==

Next steps:

1. Review config/initializers/recording_studio_trashable.rb
2. Run bin/rails generate recording_studio_trashable:migrations
3. Run bin/rails db:migrate
4. Opt recordables in explicitly with:

   include RecordingStudio::Capabilities::Trashable.to

5. Mount path: <%= options[:mount_path] %>
