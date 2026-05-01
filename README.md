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
  config.default_include_children = false
  config.default_purge_after_days = nil
  config.allow_user_retention_settings = false
  config.retention_purge_actor_resolver = -> { User.find_by!(email: "system@example.com") }
end
```

## Adding to a recordable

Recordables stay opt-in. Include the capability only on the recordable models that should be trashable:

```ruby
class Page < ApplicationRecord
  include RecordingStudio::Capabilities::Trashable.to(
    include_children: true,
    purge_after_days: 14
  )
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
- omitting `include_children:` falls back to per-recordable capability options, then addon config.
- purge refuses descendant trees unless `include_children: true` is supplied, so the addon does not orphan child recordings.
- purge only deletes recordings that are already trashed; active recordings must be trashed first.

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
  config.use_recording_studio_accessible = false
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

### Lifecycle responses

- standard lifecycle form posts redirect back to `back_path` when supplied
- when `back_path` is omitted, the controller falls back to the referrer and then a safe engine path
- async callers can request JSON with `async: true` or a JSON format request

For example, a synchronous form can just post the action and rely on the browser referrer for the default redirect-back behavior:

```erb
<%= form_with url: recording_studio_trashable.trash_recording_path(recording),
              method: :patch,
              data: { turbo: false } do %>
  <%= render FlatPack::Button::Component.new(text: "Trash", style: :primary, type: "submit") %>
<% end %>
```

## Retention

Retention settings are stored in the addon-owned `recording_studio_trashable_retention_settings` table and scoped to a subtree root recording.

Retention resolves in this order:

1. subtree retention setting saved through the mounted UI when `config.allow_user_retention_settings = true`
2. per-recordable capability option such as `purge_after_days: 14`
3. addon-wide `config.default_purge_after_days`

By default, subtree users cannot override retention through the mounted UI. When
`config.allow_user_retention_settings` is left `false`, saved subtree settings are ignored and
the mounted retention settings page is hidden and redirected away from if visited directly.

Run retention-driven purging explicitly:

```ruby
RecordingStudioTrashable.purge_due_recordings(
  scope_recording: workspace_recording,
  actor: Current.actor,
  metadata: { source: "nightly_retention_job" }
)
```

Or let the addon sweep every root recording for you:

```ruby
RecordingStudioTrashable.purge_due_recordings_for_all_scopes
```

For background or cron-driven purging, the gem now ships with both of these entry points:

- `RecordingStudioTrashable::RetentionPurgeJob.perform_later`
- `bin/rails recording_studio_trashable:purge_due`

The job and rake task default to sweeping every root recording (`parent_recording_id: nil`).
If your app uses `RecordingStudioAccessible`, set `config.retention_purge_actor_resolver`
so scheduled purges run as a real system actor that is allowed to purge.

Example Sidekiq scheduler entry:

```ruby
RecordingStudioTrashable::RetentionPurgeJob.perform_later
```

The retention purger walks due recordings leaf-first so parent recordings are only removed after due descendants are gone. Items that still require `include_children: true` stay skipped for later review.

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
