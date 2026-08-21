# Recording Studio Trashable notes

This addon requires RecordingStudio `~> 4.2` (tested with `4.2.0`). Host recordables stay opt-in through `RecordingStudio::Capabilities::Trashable.to(...)`.

## Capability registration

The engine registers `:trashable` at boot with `RecordingStudio.register_capability`. Hosts enable it on each recordable with `include RecordingStudio::Capabilities::Trashable.to(**opts)`, which wraps `RecordingStudio::Capabilities.include_for(:trashable, **options)`. Installing the gem does not enable the capability. Parent rules stay on `recording_studio_recordable`.

## Mounted UI

Mounted screens use Recording Studio core's default layout (`RecordingStudio::UsesDefaultLayout`). That shell owns back/close PageNav, flash alerts, and page width. Views call `recording_studio_page_nav` instead of inventing breadcrumbs or a second dashboard chrome.

The mounted UI is subtree-scoped. Pass a root recording id to the trash bin route and the addon will list trashed `trash_root` recordings in that subtree ordered by `trashed_at DESC`, while cascade-trashed descendants stay hidden behind their nearest explicit trash root.

Lifecycle actions redirect back by default. In standard form flows the controller can use the request referrer, and callers can still pass `back_path` when they need an explicit return location. Async callers can opt into JSON by sending `async: true` or using a JSON request format.

## Host app query defaults

Trashable does not install a `default_scope` on `RecordingStudio::Recording`, but host apps can add one when they want plain recording queries to stay on active rows:

```ruby
Rails.application.config.to_prepare do
	RecordingStudio::Recording.class_eval do
		default_scope { where(trashed_at: nil) }

		scope :not_trashed, -> { recording_studio_trashable_active }
		scope :with_trashed, -> { recording_studio_trashable_including_trashed }
	end
end
```

Use `with_trashed` in setup code, trash-bin screens, restore flows, or admin/debug tooling when you intentionally need trashed rows.

## Retention persistence

Retention settings are intentionally addon-owned so future scheduled purge jobs can evolve without reintroducing addon state into RecordingStudio core.

## Capability options

Per-recordable capability options can supply defaults such as `purge_after_days:`.

## Purge workflow

Manual purge and retention-driven purge both require targeted recordings to already be trashed.
