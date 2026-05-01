# Recording Studio Trashable notes

## Capability registration

Use `RecordingStudio.register_capability`, `RecordingStudio.enable_capability`, and `RecordingStudio.set_capability_options` exactly once per opt-in recordable model.

## Mounted UI

The mounted UI is subtree-scoped. Pass a root recording id to the trash bin route and the addon will list trashed descendants ordered by `trashed_at DESC`.

Lifecycle actions redirect back by default. In standard form flows the controller can use the request referrer, and callers can still pass `back_path` when they need an explicit return location. Async callers can opt into JSON by sending `async: true` or using a JSON request format.

## Retention persistence

Retention settings are intentionally addon-owned so future scheduled purge jobs can evolve without reintroducing addon state into RecordingStudio core.

## Capability options

Per-recordable capability options can supply defaults such as `include_children:` and `purge_after_days:`.

## Purge workflow

Manual purge and retention-driven purge both require targeted recordings to already be trashed.
