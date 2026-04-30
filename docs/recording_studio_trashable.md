# Recording Studio Trashable notes

## Capability registration

Use `RecordingStudio.register_capability`, `RecordingStudio.enable_capability`, and `RecordingStudio.set_capability_options` exactly once per opt-in recordable model.

## Mounted UI

The mounted UI is subtree-scoped. Pass a root recording id to the trash bin route and the addon will list trashed descendants ordered by `trashed_at DESC`.

## Retention persistence

Retention settings are intentionally addon-owned so future scheduled purge jobs can evolve without reintroducing addon state into RecordingStudio core.
