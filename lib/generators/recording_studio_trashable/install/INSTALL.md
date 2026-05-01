== Recording Studio Trashable installed ==

Run the migrations generator, migrate, and then opt individual recordables into
RecordingStudio::Capabilities::Trashable.

To purge expired trash without custom wrapper code, schedule one of these host-app entry points:

- `bin/rails recording_studio_trashable:purge_due`
- `RecordingStudioTrashable::RetentionPurgeJob.perform_later`

If your app uses RecordingStudioAccessible, configure
`retention_purge_actor_resolver` so scheduled purges run as a real actor with purge access.
