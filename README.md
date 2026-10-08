# Recording Studio Trashable

Recording Studio Trashable is the opt-in trash, restore, purge, retention, and mounted trash-bin addon for `RecordingStudio`.

It extracts trash behavior from RecordingStudio core into addon-owned APIs without forcing a global default scope on host apps.

## What the gem provides

- gem name: `recording_studio_trashable`
- Ruby namespace: `RecordingStudioTrashable`
- capability opt-in through `RecordingStudio::Capabilities::Trashable.to`
- namespaced lifecycle methods on `RecordingStudio::Recording`
  - `recording_studio_trashable_trash!`
  - `recording_studio_trashable_restore!`
  - `recording_studio_trashable_purge!`
- subtree trash bins with restore, purge, and retention settings UI
- optional RecordingStudioAccessible authorization integration
- addon-owned migrations for `trashed_at`, `trash_root`, and retention settings

## Installation

Add the gems to your host app. This addon requires Recording Studio 4.2.0 or newer:

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

If your host app wants ordinary recording queries to skip trashed rows by default, add a host-side extension like this:

```ruby
Rails.application.config.to_prepare do
  RecordingStudio::Recording.class_eval do
    default_scope { where(trashed_at: nil) }

    scope :not_trashed, -> { recording_studio_trashable_active }
    scope :with_trashed, -> { recording_studio_trashable_including_trashed }
  end
end
```

That keeps `RecordingStudio::Recording.all` on active rows while preserving `with_trashed` as an explicit escape hatch for trash bins, restore flows, seeds, and admin lookups.

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

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", plural_label: "Workspaces", root: true
end

class Project < ApplicationRecord
  recording_studio_recordable label: "Project", plural_label: "Projects",
                              root: false, allowed_parent_types: ["Workspace"]
end

class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", plural_label: "Folders", root: false,
                              allowed_parent_types: %w[Workspace Project Folder]
end

class Page < ApplicationRecord
  recording_studio_recordable label: "Page", plural_label: "Pages", root: false,
                              allowed_parent_types: %w[Workspace Project Folder Page]
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
  config.allow_user_retention_settings = false
  config.retention_purge_actor_resolver = -> { User.find_by!(email: "system@example.com") }
end
```

## Adding to a recordable

Recordables stay opt-in. Include the capability only on the recordable models that should be trashable:

```ruby
class Page < ApplicationRecord
  recording_studio_recordable label: "Page", plural_label: "Pages", root: false,
                              allowed_parent_types: %w[Workspace Project Folder Page]

  include RecordingStudio::Capabilities::Trashable.to(purge_after_days: 14)
end
```

That registers the addon capability on `Page` while leaving other recordables, such as `Folder`, unchanged.

## Lifecycle methods

The addon intentionally uses addon-owned method names on `RecordingStudio::Recording`:

```ruby
recording.recording_studio_trashable_trash!(
  actor: Current.actor,
  impersonator: Current.impersonator,
  metadata: { reason: "cleanup" }
)

recording.recording_studio_trashable_restore!(actor: Current.actor)
recording.recording_studio_trashable_purge!(actor: Current.actor)
```

- trash, restore, and purge operate on the targeted recording subtree.
- direct trash marks the targeted recording as a `trash_root` and hides cascade-trashed descendants from the trash bin.
- restore clears cascade-trashed descendants but leaves nested `trash_root` branches trashed until they are restored directly.
- purge only deletes recordings that are already trashed; active recordings must be trashed first.
- purge destroys descendants before parents and logs `purged` before deletion. Because purge then removes the recording and its attached events, that log entry is not durable audit history unless the host app copies it to an external audit store.

## Query helpers

The addon does not introduce a new default scope. Use explicit helpers instead:

```ruby
RecordingStudio::Recording.recording_studio_trashable_active
RecordingStudio::Recording.recording_studio_trashable_trashed
RecordingStudio::Recording.recording_studio_trashable_including_trashed
RecordingStudio::Recording.recording_studio_trashable_trash_roots
RecordingStudio::Recording.recording_studio_trashable_trash_bin
```

If your host app prefers a safer default, add a host-owned `default_scope { where(trashed_at: nil) }` and alias `recording_studio_trashable_active` to an app-facing scope such as `not_trashed`. The addon scopes that need trashed rows already call `unscope(where: :trashed_at)` so they can opt out deliberately.

`recording_studio_trashable_trash_roots` returns only explicitly trashed subtree roots.

`recording_studio_trashable_trash_bin` orders those trash roots by `trashed_at DESC` so cascade-trashed descendants do not flood the trash UI.

## Events and action names

Trashable logs through `RecordingStudio.record!` via `RecordingStudio::Recording#log_event!`.

The addon uses:

- `trashed`
- `restored`
- `purged`

`purged` is used instead of core's older `deleted` wording so permanent delete events remain distinguishable from the addon-owned soft-delete lifecycle during the extraction period.

## Authorization

By default the addon behaves like this:

- a custom resolver runs first and can allow or deny explicitly
- otherwise, if `RecordingStudioAccessible.authorized?` is loaded, authorization delegates to that adapter
- RecordingStudio core no longer provides a core `RecordingStudio::Services::AccessCheck` fallback
- if no resolver or Accessible authorizer is available, Trashable denies by default
- built-in Accessible integration can be disabled entirely
- host apps can explicitly allow permissive fallback with `config.allow_unconfigured_authorization = true`

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

The trash bin lists only `trash_root` recordings in the selected subtree. Descendants trashed by cascade stay hidden until their nearest explicit trash root is restored or purged.

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

Retention settings are stored in the addon-owned `recording_studio_trashable_retention_settings` table and scoped to a subtree root recording. Trashable also owns the `trashed_at` and `trash_root` schema it adds to `recording_studio_recordings`.

During a sweep, each recording resolves retention from the nearest saved setting on the path from that recording up to and including the sweep scope:

1. the recording's own retention setting, when `config.allow_user_retention_settings = true`
2. the nearest ancestor setting inside the sweep scope, including a saved blank value that means keep until manually purged
3. per-recordable capability option such as `purge_after_days: 14`
4. addon-wide `config.default_purge_after_days`

Settings above the sweep scope are ignored. A workspace "keep until manually purged" setting does not hide a shorter setting saved on a project inside that workspace.

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

Both entry points also support a dry-run mode so operators can preview what would be purged without deleting recordings.

The job and rake task default to sweeping every root recording (`parent_recording_id: nil`).
If your app uses `RecordingStudioAccessible`, set `config.retention_purge_actor_resolver`
so scheduled purges run as a real system actor that is allowed to purge.

Example Sidekiq scheduler entry:

```ruby
RecordingStudioTrashable::RetentionPurgeJob.perform_later
RecordingStudioTrashable::RetentionPurgeJob.perform_later(dry_run: true)
```

The retention purger walks due recordings leaf-first so parent recordings are only removed after due descendants are gone. Parents that still have active descendants stay skipped for later review.

Preview the rake task without deleting anything:

```bash
bundle exec rake recording_studio_trashable:purge_due DRY_RUN=true
```

## Internationalization

The gem ships **English only** in `config/locales/en.yml`. Keys nest under `recording_studio.trashable.*`:

```ruby
t("recording_studio.trashable.trash.title")
t("recording_studio.trashable.flashes.restored", name: page_title)
t("recording_studio.trashable.confirms.purge", name: page_title)
```

Hosts own other languages. Copy `recording_studio.trashable.*` into `config/locales/<locale>.yml` and list that locale in `config.i18n.available_locales`. Do not add `RecordingStudio_Internationalization` as a dependency of this gem — it is optional on the host (the dummy uses it to switch English/French).

Helper arguments and host translations still win. `Copy.value` and `Copy.defaulted` keep an explicit string when the host passed one, and follow the locale when the host left the English default.

Stored names stay data: recording titles, type names, and other database content are not translated.

The engine has no layout of its own. Mounted screens use Recording Studio core's default layout. Hosts should set `<html lang>` on their layout (the dummy override does this, plus `dir` when Internationalization is loaded).

Engine demo/docs pages (`/recording_studio_trashable`), generator CLI text, unknown-filter `ArgumentError`s, and other developer errors stay English.

Add [Recording Studio Internationalization](https://github.com/bowerbird-app/RecordingStudio_Internationalization) on the host when you want a language selector.

## Dummy app showcase

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

The dummy app demonstrates:

- `Workspace` as the root recordable
- `Project`, `Page`, and `Folder` recordables
- `Page` as trashable and `Folder` as non-trashable
- workspace and project scoped trash bins
- trash, restore, purge, and retention settings flows
- Recording Studio core default layout (back/close PageNav) for dummy and mounted screens
- docs pages for Setup, Configuration, Adding to a recordable, and Methods, linked from the home hub
- English and French, switched with Recording Studio Internationalization (dummy only). The language selector sits in PageNav, left of Sign out. French keys live in `test/dummy/config/locales/fr.yml`. The engine does not ship French.

## Core follow-up assumptions

Recording Studio 4 requires every configured recordable type to declare `recording_studio_recordable(...)`. Root creation must use root-declared recordables, and child recordings must be created under an allowed parent recording. This gem requires RecordingStudio `~> 4.2` (pinned to tag `v4.2.2`). Host opt-in is `include RecordingStudio::Capabilities::Trashable.to(**opts)`, a thin wrapper around `RecordingStudio::Capabilities.include_for(:trashable, **options)`. Installing this gem does not enable trash on any recordable type.

This addon:

- keeps public trash APIs addon-owned and namespaced
- owns its trash schema through addon migrations
- avoids relying on RecordingStudio core's default trash behavior or exposing new default scopes
- registers the `trashable` capability with `source: "recording_studio_trashable"` and no capability-owned `child_recordables`

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
BUNDLE_GEMFILE=$PWD/Gemfile RAILS_ENV=test bundle exec ruby -e 'require_relative "config/environment"; puts Rails.application.class.name'
bin/dev
```

The `ruby -e` check confirms the dummy app boots in the test environment without needing to keep a server running.

Then open the dummy app locally and verify the mounted surfaces still load:

- `/`
- `/recording_studio`
- `/recording_studio_trashable`
- `/recording_studio_trashable/recordings/:recording_id/trash_bin`
- `/showcase/setup`

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. If `RAILS_MASTER_KEY` is set, it writes gitignored
`test/dummy/config/master.key` so dummy credentials decrypt. Fetch-skills
always runs last. `.cursor/start.sh` starts PostgreSQL on each boot. Rebuild
with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).
