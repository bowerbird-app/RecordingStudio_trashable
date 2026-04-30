# Recording Studio Trashable

Recording Studio Trashable is the opt-in trash, restore, purge, retention, and mounted trash-bin addon for `RecordingStudio`.

It extracts trash behavior from RecordingStudio core into addon-owned APIs without adding another default scope.

## What the gem provides

- gem name: `recording_studio_trashable`
- Ruby namespace: `RecordingStudioTrashable`
- capability opt-in through `RecordingStudio::Capabilities::Trashable.to`
- namespaced lifecycle methods on `RecordingStudio::Recording`
  - `recording_studio_trashable_trash!`
  - `recording_studio_trashable_restore!`
  - `recording_studio_trashable_purge!`
- subtree trash bins with restore, purge, and retention settings UI
- optional `RecordingStudioAccessible.authorized?` integration
- addon-owned migrations for `trashed_at` compatibility and retention settings

## Installation

Add the gems to your host app:

```ruby
gem "recording_studio"
gem "recording_studio_trashable"
```

Then run:

```bash
bundle install
bin/rails generate recording_studio_trashable:install
bin/rails generate recording_studio_trashable:migrations
bin/rails db:migrate
```

## Setup

Mount the engine if you did not use the install generator:

```ruby
mount RecordingStudioTrashable::Engine, at: "/recording_studio_trashable"
```

Configure RecordingStudio normally and then configure Trashable defaults:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = %w[Workspace Project Folder Page]
  config.actor = -> { Current.actor }
end

RecordingStudioTrashable.configure do |config|
  config.authorization_roles = {
    trash: :edit,
    restore: :edit,
    purge: :admin,
    settings: :admin,
    trash_bin: :edit
  }
  config.default_purge_after_days = nil
end
```

## Adding to a recordable

Recordables stay opt-in. Include the capability only on the recordable models that should be trashable:

```ruby
class Page < ApplicationRecord
  include RecordingStudio::Capabilities::Trashable.to
end
```

That registers the addon capability on `Page` while leaving other recordables, such as `Folder`, unchanged.

## Lifecycle methods

The addon intentionally uses addon-owned method names on `RecordingStudio::Recording`:

```ruby
recording.recording_studio_trashable_trash!(
  actor: Current.actor,
  impersonator: Current.impersonator,
  metadata: { reason: "cleanup" },
  include_children: true
)

recording.recording_studio_trashable_restore!(actor: Current.actor)
recording.recording_studio_trashable_purge!(actor: Current.actor, include_children: true)
```

### Cascading

- `include_children: false` only changes the target recording.
- `include_children: true` traverses descendants for trash, restore, and purge.
- purge refuses descendant trees unless `include_children: true` is supplied, so the addon does not orphan child recordings.

## Query helpers

The addon does not introduce a new default scope. Use explicit helpers instead:

```ruby
RecordingStudio::Recording.recording_studio_trashable_active
RecordingStudio::Recording.recording_studio_trashable_trashed
RecordingStudio::Recording.recording_studio_trashable_including_trashed
RecordingStudio::Recording.recording_studio_trashable_trash_bin
```

`recording_studio_trashable_trash_bin` orders trashed recordings by `trashed_at DESC`.

## Events and action names

Trashable logs through `RecordingStudio.record!` via `RecordingStudio::Recording#log_event!`.

The addon uses:

- `trashed`
- `restored`
- `purged`

`purged` is used instead of core's older `deleted` wording so permanent delete events remain distinguishable from the addon-owned soft-delete lifecycle during the extraction period.

## Authorization

By default the addon behaves like this:

- if `RecordingStudioAccessible` is loaded, authorization delegates to `RecordingStudioAccessible.authorized?`
- if the accessible addon is unavailable, Trashable allows by default
- built-in Accessible integration can be disabled entirely
- a custom resolver can replace the built-in behavior

```ruby
RecordingStudioTrashable.configure do |config|
  config.accessible_integration_enabled = false
  config.authorization_resolver = lambda do |action:, actor:, recording:, **|
    actor.present? && action != :purge
  end
end
```

Default roles:

- trash: `:edit`
- restore: `:edit`
- purge: `:admin`
- settings: `:admin`
- trash bin: `:edit`

## Mounted UI

Mounted routes:

- `/recording_studio_trashable`
- `/recording_studio_trashable/recordings/:recording_id/trash_bin`
- `/recording_studio_trashable/recordings/:recording_id/retention_setting/edit`
- restore/purge/trash member routes for individual recordings

The mounted views are FlatPack-first and intentionally light on custom markup.

## Retention

Retention settings are stored in the addon-owned `recording_studio_trashable_retention_settings` table and scoped to a subtree root recording.

A saved `purge_after_days` value does not auto-delete by itself; it provides persisted policy data for trash bins, manual review, and future scheduled purge jobs.

## Dummy app showcase

The dummy app demonstrates:

- `Workspace` as the root recordable
- `Project`, `Page`, and `Folder` recordables
- `Page` as trashable and `Folder` as non-trashable
- workspace and project scoped trash bins
- trash, restore, purge, and retention settings flows
- sidebar docs pages for Setup, Configuration, Adding to a recordable, Cascading, and Methods

## Core follow-up assumptions

Current RecordingStudio releases may still ship built-in trash behavior and `trashed_at`.

This addon assumes the extraction is in progress, so it:

- keeps public trash APIs addon-owned and namespaced
- treats `trashed_at` migration as compatibility-safe
- avoids relying on RecordingStudio core's default trash behavior or exposing new default scopes

## Validation

From the repository root:

```bash
bundle exec rake test
```

If dummy app boot, routes, assets, or migrations change, also validate the dummy app:

```bash
cd test/dummy
bundle install
bin/rails db:setup
```
