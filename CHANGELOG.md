# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0](https://github.com/bowerbird-app/RecordingStudio_trashable/compare/recording_studio_trashable-v0.1.1...recording_studio_trashable/v1.0.0) (2026-11-23)


### ⚠ BREAKING CHANGES

* read kept recordings through core 6.14.0 ([#36](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/36))
* adopt Recording Studio 6.1 layout and Flatpack 0.1.319 ([#26](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/26))
* recording_studio_trashable now requires RecordingStudio 3.x recordable declarations and no longer supports the removed core AccessCheck fallback.

### Features

* add trashable defaults and retention purger ([2847c85](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/2847c8564443cf6c68c3f9a0015e8ca19895188d))
* adopt Recording Studio 6.1 layout and Flatpack 0.1.319 ([#26](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/26)) ([ca6b9e6](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/ca6b9e6bd907a6fcf79552e4fb36ca0137d23eeb))
* **api:** label trash bin rows and target them by recording_id ([#46](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/46)) ([82e1037](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/82e1037ec07c976e1a5e57917581927c11d3b829))
* **cursor:** add Billing 0.9.13 Cloud Agent boot ([#6](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/6)) ([2a7abd6](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/2a7abd69e0569d0144424cb129959b716e0f3d71))
* read kept recordings through core 6.14.0 ([#36](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/36)) ([7a7dc45](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/7a7dc45a223fde77f6bf9b48ac640d1cf98b7dac))
* require RecordingStudio 3.0 ([e0abfae](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/e0abfae7e55be7aec0524ef1a0bb026faff2ba94))
* **retention:** store purge_at and select due rows in one query ([#31](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/31)) ([ce2f201](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/ce2f201c73dac84ab686ed1b9692989f4584af9b))
* tighten trash auth and retention flows ([577d9af](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/577d9af3826726e3c5502cccb4c0512b88f763f3))
* wrap trashable enablement with core 4.2 include_for factory ([#5](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/5)) ([1e1c0f7](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/1e1c0f7f3b4f418f3015ec78769aacb8024c2ed8))


### Bug Fixes

* **api:** per-type trash action titles and override_openapi ([#48](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/48)) ([a07eb60](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/a07eb60cd0a711f10ee601191c095df3485f96de))
* **api:** serialize trash results with full API context ([#49](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/49)) ([d4b82bd](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/d4b82bdf8fa62e5cdc320787fc9a1f9815b081e7))
* **api:** use plain trash action titles and a Trash tag suffix ([#45](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/45)) ([b0c8d90](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/b0c8d90c0f80866d95a42b38831050c5e3d18141))
* **importmap:** stop modulepreloading trashable controllers ([#51](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/51)) ([6dbfb58](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/6dbfb5862c010f5653e96e731332f1b26f9f2050))
* restore dummy app engine pages ([61342d7](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/61342d732fbae4191f2e72257c85e3662d993264))
* tighten mounted auth and retention semantics ([490a7c4](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/490a7c435f510bf9a5884f23fe3c06466b14cce7))

## [Unreleased]

## [1.3.2] - 2026-11-23

### Added

- Named Recording Studio MCP tools for each trashable type, when MCP 0.45 or newer is loaded. Names come from `RecordingStudioMcp.tool_name`. A page gets `trash_page`, `restore_page`, `purge_page`, and `list_pages_trash_bin`. Trash, restore, and purge stay singular. The trash bin tool uses MCP's declared plural, so a plural label of "Press centres" is `list_press_centres_trash_bin`. `Admin::Page` is still `trash_page` and `list_pages_trash_bin`.
- `list_<plural type>_trash_bin` lists trash roots so restore and purge have an id. Purge still deletes only an item that is already in the trash, and it deletes that subtree. Restore still brings back the item and the children that were trashed with it.

### Changed

- OpenAPI descriptions for trash, restore, purge, and list trash bin describe the endpoint, the subtree, and the 404 and 422 cases. They do not name access roles. MCP tool descriptions stay in `McpCopy::Copy`. `override_openapi` still replaces the OpenAPI title and description. The description override does not change the MCP tool description. A title override still does.

### Upgrade Notes

- Bump to `1.3.2`. No migration. No host action. Screens are unchanged. OpenAPI descriptions for these four actions changed. Hosts that do not load Recording Studio MCP do not get the named tools.
- To turn the tools on, add `recording_studio_mcp`, `>= 0.45`, `< 0.46`, to the app Gemfile. This gem does not depend on it. `RecordingStudioTrashable::Api.register!` registers the tools, and it does nothing when MCP is absent.
- Set `public_name` on an API type only when two trashable types would share one snake_case name. This gem does not set `public_name`.
- An `override_openapi` description changes the OpenAPI document only. A title override still changes the MCP tool title.

## [1.3.1] - 2026-11-20

### Fixed

- Denied trash, restore, and purge raise `RecordingStudio::AuthorizationError` instead of `ArgumentError`. Recording Studio MCP already maps that class in `TOOL_ERROR_CLASSES`, so a denied tool call is a tool error instead of JSON-RPC `-32603` Internal error. Argument bugs still raise `ArgumentError`.

### Upgrade Notes

- Bump to `1.3.1`. No migration. No host action unless a caller rescued `ArgumentError` for a trashable denial. Rescue `RecordingStudio::AuthorizationError` for that case. API still returns forbidden. Mounted UI still shows the not-authorized flash or lifecycle alert.

## [1.3.0] - 2026-11-19

### Changed

- Development Gemfiles pin `recording_studio` `~> 7.8` at tag `v7.8.0`, `flat_pack` `~> 0.2` at tag `v0.2.0`, and `recording_studio_metrics` `~> 0.10` at tag `v0.10.0`.
- Dummy pins `recording_studio_accessible` `v0.56.0`, `recording_studio_api` `v1.19.0`, `recording_studio_admin` `v2.19.1`, `recording_studio_logs` `v0.8.2`, `recording_studio_moveable` `v6.0.3`, `recording_studio_icons` `v0.5.0`, and `recording_studio_internationalization` `v0.3.1`.
- The dummy importmap drops the manual `flat_pack/heroicons` pin. The dummy app does not copy the Recording Studio 7.4, 7.5, or 7.7 migrations.

### Upgrade Notes

- Bump to `1.3.0`. No Trashable migration. The gemspec floors stay `recording_studio >= 7.0`, `< 8.0`, `flat_pack >= 0.1.315`, and `recording_studio_metrics >= 0.3.0`, `< 1.0`.
- Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not.
- flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration.

## [1.2.3] - 2026-11-18

### Changed

- Development Gemfiles pin `recording_studio` tag `v7.7.1`, `flat_pack` tag `v0.1.378`, and `recording_studio_metrics` tag `v0.9.2`.
- Dummy pins `recording_studio_accessible` `v0.54.1`, `recording_studio_api` `v1.16.0`, `recording_studio_admin` `v2.19.0`, `recording_studio_logs` `v0.8.1`, `recording_studio_moveable` `v6.0.2`, `recording_studio_icons` `v0.4.2`, and `recording_studio_internationalization` `v0.3.1`.
- The dummy app adds `config/recording_studio_api.yml` (`shared: {}`) and copies API migration `20261117000024_add_owner_to_recording_studio_api_api_clients`. It does not copy the Recording Studio 7.4, 7.5, or 7.7 migrations.

### Upgrade Notes

- Bump to `1.2.3`. No Trashable migration. The gemspec floors stay `recording_studio >= 7.0`, `< 8.0` and `recording_studio_metrics >= 0.3.0`, `< 1.0`.
- Hosts moving to Recording Studio 7.7 must run the Recording Studio 7.4, 7.5, and 7.7 migrations. The dummy app leaves those three out.
- A host that mounts Recording Studio API 1.12 or newer needs `config/recording_studio_api.yml`. `shared: {}` is enough. API 1.16 `ProvisionApiClient` writes `owner`, so copy `20261117000024_add_owner_to_recording_studio_api_api_clients` before provisioning clients.

## [1.2.2] - 2026-11-18

### Fixed

- The trash bin live search controller is pinned with `preload: false`. Host pages no longer modulepreload `controllers/recording_studio_trashable/live_search_controller`.

### Upgrade Notes

- Bump to `1.2.2`. No host action. No migration. Hosts that eager-load `controllers/` still get the controller. Lazy-load hosts fetch it on first use. Landing pages no longer modulepreload it.

## [1.2.1] - 2026-11-18

### Fixed

- `trashable_trash`, `trashable_restore`, and each `trashable_list_trash_bin` record serialize with the caller's API version, API key, and relationship context. Declared fields that need that grant are filled, matching show for the same recording. Trash-bin records still add `label` and `recordable_type`. `trashable_purge` still returns `id` and `purged`.

### Upgrade Notes

- Bump to `1.2.1`. No migration. No host change. Trash, restore, and trash-bin JSON now include the same declared resource fields as show. Purge is unchanged. A caller with no access grant still gets the previous payload and no error.

## [1.2.0] - 2026-11-18

### Fixed

- Trash, restore, purge, and list trash bin OpenAPI titles are per recordable type. The title is the verb plus the recordable label in lowercase: "Trash page", "Restore video", "Purge support page", "List press center trash bin". `tag_suffix` stays `Trash`. Capability titles stay Trash, Restore, Purge, and List trash bin.

### Added

- `RecordingStudioTrashable::Api.override_openapi(type:, action:, title:, description:)` replaces the derived title and description for one type and one action. `openapi_for(type:, action:)` returns that override. A type that is not in `recordable_types` returns nil, and MCP keeps the capability title. An override for that type still wins.

### Upgrade Notes

- Bump to `1.2.0`. No migration. No host change. Declared recordable types get the derived titles. Call `override_openapi` only when one type needs different words. Action names, handlers, roles, inputs, and response bodies are unchanged.

## [1.1.1] - 2026-11-17

### Fixed

- `Recording.kept` and `RecordingStudio.kept_sql` no longer treat a database error as a missing `trashed_at` column. That used to apply no filter (`1=1`), so trashed rows stayed in kept results. A missing `trashed_at` column still applies no filter. `ActiveRecord::NoDatabaseError` still applies no filter, so `db:create` and `assets:precompile` work before the database exists. Other ActiveRecord errors, including `ConnectionNotEstablished` and `StatementInvalid`, raise.

### Upgrade Notes

- Bump to `1.1.1`. No migration. A host with no `trashed_at` column still gets no kept filter and no error. A missing database still gets no filter and no error. A connection failure or a bad statement now raises instead of showing trashed rows as kept.

## [1.1.0] - 2026-11-17

### Added

- Trash bin records include `label` and `recordable_type`. `label` is the recordable title, then its name, then `"<Type> #<first 8 of id>"`. The trash bin screen uses the same rule.
- `trashable_restore` and `trashable_purge` accept an optional `recording_id` from a List trash bin record. Pass it when the action is called on the parent to restore or purge that nested trash root.
- Restore and purge of a recording that is already trashed no longer require that type to opt into trashable. Trash still does.

### Upgrade Notes

- Bump to `1.1.0`. No migration. Leave `recording_id` out and restore and purge keep the previous behavior.
- Trash bin records still include the fields they had. `label` and `recordable_type` are added on each record.
- Call restore or purge on the parent and pass `recording_id` to target a nested trash root whose type does not register those actions. The id has to be a trash root in that parent's subtree. Anything else is not found.
- A type that does not include trashable can still be restored or purged once it is already in the trash. Trashing that type still requires the capability.

## [1.0.4] - 2026-11-17

### Changed

- OpenAPI titles for trash, restore, purge, and list trash bin are `Trash`, `Restore`, `Purge`, and `List trash bin`.
- Those four actions set `tag_suffix` to `Trash` in the same OpenAPI metadata. MCP can group a type's actions under a heading such as `Video Trash`.

### Upgrade Notes

- Bump to `1.0.4`. No migration. Action names, descriptions, inputs, roles, and response bodies are unchanged.
- Match the new titles if a client compared the old `Trash - ` titles. `tag_suffix` is metadata for that grouping. This gem does not depend on the MCP gem.

## [1.0.3] - 2026-11-17

### Changed

- API and MCP descriptions for trash, restore, purge, and list trash bin now say what each action does, when to choose it, where the recording id comes from, and the JSON it returns.

### Upgrade Notes

- Bump to `1.0.3`. No migration. Handlers, inputs, roles, and response bodies are unchanged.

## [1.0.2] - 2026-11-17

### Changed

- Development Gemfiles pin `recording_studio` tag `v7.4.0`, `flat_pack` tag `v0.1.377`, and `recording_studio_metrics` tag `v0.9.1`.
- Dummy pins `recording_studio_accessible` `v0.46.0`, `recording_studio_api` `v1.3.0`, and `recording_studio_icons` `v0.4.1`. The dummy Flatpack pin was already `v0.1.377`.
- The dummy app does not copy Recording Studio 7.4.0's optional index migration for `index_rs_recordings_on_root_type_created_at_id`.

### Upgrade Notes

- Bump to `1.0.2`. No Trashable migration. The gemspec floor stays `recording_studio >= 7.0`, `< 8.0`.
- Development and CI now install Recording Studio `v7.4.0`. Hosts that want the optional `(root_recording_id, recordable_type, created_at, id)` index copy that core migration themselves.
- API `v1.3.0` omits list `meta.total_count` unless the request passes `include_total=true`. This dummy does not read `meta.total_count`.

## [1.0.1] - 2026-11-16

### Changed

- Dummy app pins refreshed to the latest release tags.
- API actions for restore, purge, and the trash bin list opt into `include_trashed` for API 1.2.
- Puma `8.1.1` in the dummy lock.

### Upgrade Notes

- Bump to `1.0.1`. No migration.
- Restore, purge, and the trash bin list request trashed rows. Trash stays on kept rows.

## [1.0.0] - 2026-11-16

### Removed

- `RecordingStudioTrashable::Hooks`.
- `RecordingStudioTrashable.configuration.hooks`.
- The `:hooks_registered` key on `RecordingStudioTrashable.configuration.to_h`.
- Engine initializers `recording_studio_trashable.before_initialize` and `recording_studio_trashable.after_initialize`.
- The `:on_configuration` run inside `recording_studio_trashable.load_config`.

### Upgrade Notes

- Bump to `1.0.0`. No migration.
- Delete references to `RecordingStudioTrashable::Hooks` and `RecordingStudioTrashable.configuration.hooks`.
- Register those hooks on `RecordingStudio.configuration.hooks`. Core runs that registry. This gem does not call it at boot.
- Stop reading `:hooks_registered` from `RecordingStudioTrashable.configuration.to_h`.
- Sibling gemspecs that only need the query helpers should depend on `recording_studio_trashable`, `"~> 1.0"`.
- Accessible `v0.45.0` still requires `>= 0.17.0, < 1.0`. Admin `v2.16.0` still requires `>= 0.16.1, < 1.0`. Those releases cannot be installed with Trashable `1.0.0`.
- Trash, restore, purge, trashed rows, and `purge_at` are unchanged.

## [0.17.0] - 2026-11-15

### Changed

- Gemspec requires `recording_studio` `>= 7.0`, `< 8.0`. `recording_studio_metrics` stays `>= 0.3.0`, `< 1.0`.
- Development Gemfiles pin `recording_studio` tag `v7.0.0`, `recording_studio_metrics` tag `v0.9.0`, and `flat_pack` tag `v0.1.376`.
- Dummy pins that rejected Recording Studio 7 move to releases that allow it: `recording_studio_accessible` `v0.43.1`, `recording_studio_admin` `v2.16.0`, and `recording_studio_internationalization` `v0.3.0`. `recording_studio_api` stays `v0.23.4`, `recording_studio_logs` stays `v0.7.5`, `recording_studio_moveable` stays `v4.2.0`, `recording_studio_icons` stays `v0.2.1`, and `view_component` stays `4.19.0`.
- Dummy seeds and tests that created a workspace root with `RecordingStudio.root_recording_for` now call `RecordingStudio.create_root_recording!`.
- The dummy app sets `config.authorize_write` to allow a write when an actor is present. It does not set `allow_unauthorized_writes`.

### Upgrade Notes

- Bump to `0.17.0`. No new Trashable migration.
- Require Recording Studio `>= 7.0`, `< 8.0`. `root_recording_for` only finds a root. Create one with `RecordingStudio.create_root_recording!(recordable, actor:)`.
- Set `config.authorize_write` and pass an actor. `create_root_recording!` calls the authorizer with `root_recording` nil. Do not set `allow_unauthorized_writes`.
- Hosts that install the dummy's companion set should use the tags above. Metrics development pin is `v0.9.0`.

## [0.16.1] - 2026-11-15

### Changed

- Allow recording_studio < 8.0 (core 7 phase 1). The floor stays `>= 6.14.0`. Development Gemfiles still pin tag `v6.14.0`.

### Upgrade Notes

- Bump to `0.16.1`. No new migration. Hosts may depend on Recording Studio 7. This gem's test app stays on core 6.14.0.

## [0.16.0] - 2026-11-14

### Removed

- `Recording.recording_studio_trashable_active`, `recording_studio_trashable_including_trashed`, `recording_studio_trashable_kept_sql`, and `recording_studio_trashable_trashed_sql`. `Recording.kept` and `RecordingStudio.kept_sql` replace them.
- The documented host `default_scope { where(trashed_at: nil) }`. Plain recording queries include trashed rows. Call `.kept` to skip them.

### Changed

- The engine registers `RecordingStudio.register_recording_filter(:trashable)` once from an initializer. `Recording.kept` hides trashed rows. `RecordingStudio.kept_sql` quotes a table alias and returns the same condition. A host with no `trashed_at` column, or no database yet, gets no filter and no error.
- `RecordingStudioTrashable.void_recording!` sets `trashed_at` with `update_columns` on the recording and its descendants. It still skips validations, callbacks, capability checks, authorization, events, `trash_root`, and `purge_at`.
- Gemspec requires `recording_studio` `>= 6.14.0`, `< 7.0`. Development Gemfiles pin tag `v6.14.0` and `flat_pack` tag `v0.1.374`. Dummy pins `recording_studio_accessible` `v0.40.0`, `recording_studio_api` `v0.23.2`, `recording_studio_logs` `v0.7.5`, `recording_studio_moveable` `v4.2.0`, and `recording_studio_internationalization` `v0.2.2`. `recording_studio_metrics` stays `v0.8.0`, `recording_studio_admin` stays `v2.13.0`, `recording_studio_icons` stays `v0.2.1`, and `view_component` stays `4.19.0`.
- Trash-bin scopes stay: `recording_studio_trashable_trashed`, `recording_studio_trashable_trash_roots`, `recording_studio_trashable_trash_bin`, and `recording_studio_trashable_filter` (`:active` calls `kept`).

### Upgrade Notes

- Bump to `0.16.0`. No new Trashable migration. Require Recording Studio `>= 6.14.0`, `< 7.0`.
- The pin refresh merged after `0.15.0` without a version bump, so those dependency pins ship in `0.16.0`.
- Replace `recording_studio_trashable_active` with `Recording.kept`. Replace `recording_studio_trashable_kept_sql(alias)` with `RecordingStudio.kept_sql(alias)`. Delete `recording_studio_trashable_including_trashed` and read the unfiltered relation. Delete host `default_scope` on `trashed_at`.
- `void_recording!` now voids descendants. Callers that voided one row and left children kept will see those children leave `Recording.kept`.
- Sibling gems that only need the filter should `require "recording_studio_trashable/query"` and depend on `~> 0.16`.

## [0.15.0] - 2026-11-14

### Changed

- Recording scopes register once with `RecordingStudio.configuration.hooks.extend_model(:recording)`. Core reapplies that proc when `Recording` reloads. `install_query_helpers!` and the query-path `ActiveSupport::Reloader.to_prepare` hook are gone.
- `require "recording_studio_trashable/query"` still adds `RecordingScopes` to `RecordingStudio::Recording`, including when `Recording` is already loaded and after a reload.
- The full gem includes those scopes after `RecordingStudio.apply_capabilities!`, so `RecordingScopes` stays ahead of the trashable recording methods.

### Upgrade Notes

- Bump to `0.15.0`. No new migration.
- Host initializers that hid trashed rows inside `to_prepare` with `RecordingStudio::Recording.class_eval` should register `RecordingStudio.configuration.hooks.extend_model(:recording)` once, when the initializer loads. Do not put that registration in `to_prepare`. Each run adds another proc, and the scopes stack.
- `RecordingStudioTrashable.install_query_helpers!` is removed. Keep `require "recording_studio_trashable/query"`.

## [0.14.1] - 2026-11-14

### Changed

- Gemspec requires `recording_studio` `>= 6.7.1`, `< 7.0`. The previous floor was `>= 6.1.0`. Hosts need Recording Studio 6.7.1 so core reloads extensions correctly.
- Development Gemfiles pin `recording_studio` to tag `v6.10.0`. `flat_pack` stays tag `v0.1.356` and `recording_studio_metrics` stays tag `v0.8.0`. Dummy stays on `recording_studio_accessible` `v0.31.0`, `recording_studio_admin` `v2.13.0`, `recording_studio_api` `v0.22.1`, `recording_studio_logs` `v0.7.4`, `recording_studio_moveable` `v4.1.1`, `recording_studio_icons` `v0.2.1`, and `recording_studio_internationalization` `v0.2.0`. `view_component` stays `4.19.0`.
- Dummy `RecordingStudio.configure` sets `config.authorize_write` so Recording Studio 6.5+ accepts writes from a present actor.

### Upgrade Notes

- Bump to `0.14.1`. This gem ships no new migration.
- Require Recording Studio `>= 6.7.1`, `< 7.0`. Development and CI pin tag `v6.10.0`.
- Recording Studio 6.9.0 and 6.10.0 store `root_recording_id` on `recording_studio_events`. Copy core migration `20261114090000_add_root_recording_id_to_recording_studio_events` into the host app before writing events on those releases. The dummy app includes that copy.
- Trash, restore, purge, `trash_root`, retention, and the query entry point are unchanged.

## [0.14.0] - 2026-11-12

### Added

- Nullable `purge_at` on `recording_studio_recordings`, plus partial index `idx_rs_recordings_due_purge_at` on `purge_at` where `trashed_at` is present.
- Trash sets `purge_at` to `trashed_at` plus the retention days on the trash root and every newly trashed descendant. A blank day count stores null. Restore clears `purge_at` on the rows it restores. A nested trash root stays trashed and keeps its date.
- Saving or deleting a retention setting restamps `purge_at` for trashed rows in that recording's subtree.
- `bin/rails recording_studio_trashable:restamp_purge_at` recomputes `purge_at` for current trash. Pass `SCOPE_RECORDING_IDS` to limit the subtrees. Running it again writes the same dates.

### Changed

- Retention purge loads trashed rows with `purge_at` at or before `as_of` in one query, optionally limited to the given scope ids. It does not load active rows. Parents that still have an active or not-yet-due descendant stay skipped. Due rows are still deleted deepest first, then by `trashed_at`, and the log action is still `purged`.

### Upgrade Notes

- Bump to `0.14.0`. This release is additive. Install the new migration with `bin/rails generate recording_studio_trashable:migrations`, then `bin/rails db:migrate`.
- Run `bin/rails recording_studio_trashable:restamp_purge_at` once after migrating. Rows trashed before the upgrade have a null `purge_at` and are not purged until that backfill runs. Run the task again after you change `default_purge_after_days` or a recordable's `purge_after_days`.
- `purge_due_recordings`, `purge_due_recordings_for_all_scopes`, `RetentionPurgeJob#perform`, and `recording_studio_trashable:purge_due` keep their signatures. `dry_run` still deletes nothing. You still need `retention_purge_actor_resolver` when Accessible is on.

## [0.13.0] - 2026-11-12

### Added

- Trash, restore, purge, and list-trash-bin on Recording Studio API as capability actions (`:trashable`) named `trashable_trash`, `trashable_restore`, `trashable_purge`, and `trashable_list_trash_bin`. Hosts that already mount the API get them on types that enable Trashable. MCP sees them on the generic `capability_action` path.
- `trashable_trash` and `trashable_restore` require `:edit`. `trashable_purge` requires `:admin`. `trashable_list_trash_bin` requires `:edit`, matching the trash bin screen, and also calls `RecordingStudioTrashable.authorized?(action: :trash_bin)`.
- Handlers call `recording_studio_trashable_trash!`, `recording_studio_trashable_restore!`, `recording_studio_trashable_purge!`, and `SubtreeQuery.trashed_recordings_for_query`. Lookup uses `access_grant.accessible_recordings(include_trashed: true)`. Recording Studio API already authorizes the grant at the action `required_role` with `include_trashed: true` before the handler. `trashable_list_trash_bin` also calls `RecordingStudioTrashable.authorized?(action: :trash_bin)`.
- `trashable_list_trash_bin` strips `q`, orders by `trashed_at DESC, id DESC`, and pages with `page` / `per_page` defaulting to 25 and capped at 100.
- Dummy mounts Recording Studio API `v0.21.3` in development and test so those HTTP paths can be exercised. Dummy `recordable_types` keep the host Workspace/Project/Folder/Page list, then add Access and API types. `AdminRoot` is registered only when Recording Studio API is loaded, because `RecordingStudioApi::AdminApi` lists it as an allowed parent.

### Upgrade Notes

- Bump to `0.13.0`. No migration.
- This gem still does not depend on Recording Studio API. When the API gem is loaded, Trashable registers the actions on every named API. Registering twice with the same handler is a no-op. A different handler for the same name raises.
- Enable the actions on a type by including `RecordingStudio::Capabilities::Trashable.to` and exposing that type on the API (`auto_capability_actions` stays on unless you turn it off).
- Metrics stay on `:operations` through `RecordingStudioTrashable::Metrics.register!`. This change does not call `RecordingStudioMetrics::Api.register!`.

## [0.12.3] - 2026-11-05

### Security

- Development lockfiles move Rails to `8.1.4.1`. Dummy also moves `net-ssh` to `7.3.8`. `rack` stays `3.2.8`, `nokogiri` `1.19.7`, `loofah` `2.25.3`, and `rails-html-sanitizer` `1.7.2`. Gemspec floors are unchanged.

### Upgrade Notes

- Bump to `0.12.3`. Re-bundle to pick up Rails `8.1.4.1`. No migration. Trash, restore, purge, `trash_root`, and the query entry point are unchanged.

## [0.12.2] - 2026-11-04

### Changed

- Development Gemfiles pin `recording_studio` to tag `v6.3.0`, `flat_pack` to GitHub tag `v0.1.341`, and `recording_studio_metrics` to tag `v0.7.2`. Dummy also pins `recording_studio_internationalization` to tag `v0.2.0`. `view_component` stays at `4.19.0`. Gemspec floors are unchanged (`recording_studio >= 6.1.0`, `flat_pack >= 0.1.315`, `recording_studio_metrics >= 0.3.0, < 1.0`).
- Lockfiles pick up transitive bumps from those pins, including Rails `8.1.4`, `nokogiri` `1.19.7`, `i18n` `1.15.2`, `rack` `3.2.8`, `rdoc` `8.1.0`, and `net-protocol` `0.4.0`. Dummy also moves `action_text-trix` to `2.1.19` and `minitest` to `6.0.6`.

### Security

- Trash bin table cells that render a recording label or recordable type through FlatPack `html:` now HTML-escape those values.

### Upgrade Notes

- Bump to `0.12.2`. Pin `recording_studio` to tag `v6.3.0`, `flat_pack` to tag `v0.1.341`, and Metrics to `v0.7.2`. Dummy/host Internationalization can pin `v0.2.0`. Keep `view_component` at `4.19.0`.
- No migration. Trash, restore, purge, `trash_root`, and the query entry point are unchanged.

## [0.12.1] - 2026-10-28

### Changed

- Development Gemfiles pin `recording_studio_metrics` to tag `v0.7.0` and dummy `recording_studio_internationalization` to tag `v0.1.8`, which accept `recording_studio >= 6.1.0` without a Bundler gemspec shim.
- Committed SimpleCov output under `coverage/` and `test/dummy/coverage/` is untracked and gitignored.
- Sibling gemspec example for the query entry point is `recording_studio_trashable ~> 0.12`.

### Removed

- `test/support/widen_recording_studio_requirement.rb` (`Gem::Specification.prepend` that rewrote sibling `recording_studio` requirements).
- Dead dummy template workflow `test/dummy/.github/workflows/ci.yml`.
- Template leftovers: `docs/gem_template/`, `UPDATE_SUMMARY.md`, `MIGRATION_NOTES.md`, unused dummy `hello_controller.js`, and RuboCop excludes for nonexistent `lib/gem_template` paths.

### Upgrade Notes

- Pin Metrics `v0.7.0`. Dummy/host Internationalization can pin `v0.1.8`. Delete any copy of `widen_recording_studio_requirement.rb`.
- No migration. Trash, restore, purge, `trash_root`, and the query entry point are unchanged.

## [0.12.0] - 2026-10-26

### Changed

- Requires `recording_studio >= 6.1.0` (git tag `v6.1.0`) and `flat_pack >= 0.1.315` (development pin commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56`, `FlatPack::VERSION` `0.1.319`). `view_component` resolves to `4.19.0` (`>= 4.14, < 5` from Flatpack).
- Mounted screens use the Recording Studio 6.1 layout. `RecordingStudioTrashable.configuration.layout` replaces the unused `full_page_layout` setting. `nil` follows `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`.
- Engine and dummy views set `content_for :title` / `:subtitle`, `flat_pack_page_nav`, and `register_page_nav`. Page headings render once, from the layout.
- The dummy top nav does not render a language selector. Locale coverage posts `locale` to the Internationalization endpoint.

### Upgrade Notes

- Bump to `0.12.0`. Pin `recording_studio` to tag `v6.1.0` and `flat_pack` to ref `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (or tag `v0.1.315` or newer). Lock `view_component` at `4.19.0`.
- Remove `include RecordingStudio::UsesDefaultLayout`, `layout "recording_studio/default_layout"`, and `recording_studio_page_nav`. Call `recording_studio_layout { RecordingStudioTrashable.configuration.layout }` on controllers that render these screens.
- Replace `config.full_page_layout` with `config.layout`. Accepted values are `nil`, `false`, a layout name, or a callable invoked as `call(controller:)`.
- Move the visible page heading to `content_for :title` (and `content_for :subtitle` when the page has one). Put back and close on `flat_pack_page_nav`. Put page actions on `register_page_nav`, or `recording_studio_page_nav_right` when the control is not a link.
- If a sibling gemspec still requires `recording_studio` below 6, load `test/support/widen_recording_studio_requirement.rb` before Bundler evaluates gemspecs. Metrics `v0.5.0` and Internationalization `v0.1.2` need that hook.
- No migration. Trash, restore, purge, `trash_root`, and the query entry point are unchanged.

## [0.11.3] - 2026-10-22

### Changed

- Runtime range for `recording_studio_metrics` is now `>= 0.3.0, < 1.0` (CI tested with 0.5.0). No code change.

### Upgrade Notes

- Bump to `0.11.3`. Gemfile pins can stay on Metrics `v0.5.0`. The gemspec range is `>= 0.3.0, < 1.0` (CI tested with 0.5.0).

## [0.11.2] - 2026-10-20

### Changed

- Requires `recording_studio_metrics` `>= 0.3.0, < 0.6` (git tag `v0.5.0`).
- Dummy and development Gemfiles pin Metrics `v0.5.0`.

### Upgrade Notes

- Bump to `0.11.2`. Pin `recording_studio_metrics` to tag `v0.5.0` (`>= 0.3.0, < 0.6`).
- Metric registration is unchanged. This gem does not call `RecordingStudioMetrics::Admin.chart_series`, so the 0.5 `{ x:, y: }` point shape does not affect Trashable.

## [0.11.1] - 2026-10-16

### Changed

- Requires `recording_studio_metrics` `>= 0.3.0, < 0.4` (git tag `v0.3.1`).
- README lists MCP 0.17.0 catalog tool names for trash metrics. `from`, `to`, and `interval` apply only to `trash.trashed_over_time`.
- Dummy trash-metrics tests assert each registry identifier hyphenates to that MCP tool name, and that `find` succeeds before catalog metadata is read.

### Upgrade Notes

- Bump to `0.11.1`. Pin `recording_studio_metrics` to tag `v0.3.1` (`>= 0.3.0, < 0.4`).
- Metric registration is unchanged. The engine still calls `RecordingStudioTrashable::Metrics.register!` on reload, with `api_authorize` as `RecordingStudioTrashable::Api::Access.can_view?`. This gem still does not call `RecordingStudioMetrics::Api.register!`.

## [0.11.0] - 2026-10-14

### Added

- English fallback for shipped `recording_studio.trashable.*` keys when the active locale has no translation: `Copy.t` / `trashable_t` resolve through `RecordingStudio.t`, which uses the loaded `:en` translation (host English overrides included), then the caller's `default:`, then an eager-loaded, deep-frozen merge of this gem's `config/locales/en.yml` registered at boot via `RecordingStudio::Translation.register_shipped_english`.
- Behavioral coverage for parity with `I18n.t`, fallback order, `_html` escaping, boot registration, Rails reloader reset, drift guard against hand-copied English `default:`s, and real-page deleted-key / boot host-override renders.

### Changed

- Requires `recording_studio ~> 4.7` (pinned to tag `v4.7.0`).
- Removed hand-copied English `default:` strings from `Copy.t` / `trashable_t` call sites that matched `en.yml`. Unknown action tokens still pass `default: name` through `Copy.action_name`.

### Upgrade Notes

- Bump to `0.11.0` and ensure the host uses Recording Studio `~> 4.7`.
- Fallback comes from the loaded English, host overrides included.
- No migration or host code change is required for English hosts.
- Only `recording_studio.trashable.*` keys go through `RecordingStudio.t` / `Copy.t`. Host or other-namespace keys stay on `I18n.t` with the same defaults as main.
- A missing `_html` key with a non-interpolating caller `default:` stays unsafe like view `t`. An interpolating caller `default:` escapes args and returns `html_safe` (stricter than view `t`). A plain `default:` with no interpolation is returned as a plain (non-`html_safe`) String, so views will escape it.
- Prefer `Copy.t` / `RecordingStudio.t` for gem keys when adding new call sites; do not hand-copy English `default:` strings that match `en.yml`.

## [0.10.0] - 2026-10-13

### Added

- Lightweight query entry point `require "recording_studio_trashable/query"` for sibling gems that need kept/trashed scopes, predicates, SQL fragments, and `void_recording!` without loading the Rails engine.
- Query path installs `RecordingScopes` only (via `install_query_helpers!` and `ActiveSupport::Reloader.to_prepare`, so Zeitwerk-loaded `RecordingStudio::Recording` gets the helpers after boot and after reload). It does not add importmap/asset paths, register the `:trashable` capability, include CopyHelper, register trash metrics, or require `flat_pack` / `recording_studio_metrics` at runtime.
- README section documenting sibling gemspec dependency (`~> 0.10`), `require: false` when needed, and the query require line plus helper calls.

### Changed

- `RecordingScopes` and `void_recording!` live under `lib/recording_studio_trashable/recording_scopes.rb` and `lib/recording_studio_trashable/query.rb`. The default `require "recording_studio_trashable"` still loads the query helpers first, then the engine, capability, CopyHelper, and metrics — behavior for full-engine hosts stays the same.

### Upgrade Notes

- Bump to `0.10.0`. No migration.
- Full-engine users (`require "recording_studio_trashable"`) need no code changes. Importmap pins, modulepreloads, capability registration, Recording lifecycle methods, CopyHelper, and trash metrics stay as before.
- Sibling gems that previously depended on Trashable only for SQL/scope helpers should switch to `require "recording_studio_trashable/query"` (and `require: false` on Gemfile entries that would auto-require the gem name) so they do not pull engine side effects when the host is not mounting Trashable UI.

## [0.9.0] - 2026-10-13

### Added

- Sibling-facing trash ownership helpers on every `RecordingStudio::Recording` (via `RecordingScopes`, not only Trashable-enabled recordables):
  - predicates `recording_studio_trashable_trashed?` and `recording_studio_trashable_kept?`
  - SQL fragments `recording_studio_trashable_kept_sql(table)` and `recording_studio_trashable_trashed_sql(table)` for joins and recursive CTEs (identifiers validated and quoted per part; schema-qualified names with exactly one dot allowed; `nil` rejected)
  - `RecordingStudioTrashable.void_recording!` / `recording_studio_trashable_void!` for single-row soft-void through `update_columns(trashed_at:, updated_at:)` so validations and callbacks do not run (required for Oauth Access grant voids; no cascade, capability, auth, events, or `trash_root`)
- README mapping of raw `trashed_at` call sites in accessible, api, Embeddable, admin, Oauth, presskits, and support to these APIs, including `~> 0.9` dependency guidance, column-existence conditionals, `merge` caveat, `unscoped.recording_studio_trashable_active` for admin/Oauth lookups, and Embeddable partial-index unqualified `trashed_at IS NULL` guidance.

### Upgrade Notes

- Bump to `0.9.0`. No migration.
- Existing Trashable callers are unchanged. Sibling gems (`accessible`, `api`, `Embeddable`, `admin`, `Oauth`) should depend on `recording_studio_trashable ~> 0.9` and keep column-existence guards when migrating off raw `trashed_at`. Oauth void must use `void_recording!` (`update_columns`), not `recording_studio_trashable_trash!` and not `update!`.

## [0.8.0] - 2026-10-12

### Added

- English Rails I18n keys for non-view copy under `recording_studio.trashable` (controller flashes, retention validation messages, purge summary strings, and overview authorization action labels) already resolve through `Copy.t` with English `default:` so a host locale without a fallback never shows "translation missing".
- Overview authorization `<dt>` labels render via `Copy.action_name` (keys under `recording_studio.trashable.actions.*`, including `settings` and `trash_bin`). English output stays byte-identical to main's raw action tokens.
- Host English override coverage: test-only fixture `test/dummy/test/locales/trashable_host_override.en.yml` loaded via `I18n.backend.load_translations` (no `I18n.load_path` mutation) plus a real-page assert.
- Always-loaded boot-order guard `test/dummy/config/locales/recording_studio_trashable_host.en.yml` for the rarely shown `flashes.retention_managed` key, with a render assert on the retention-managed redirect.
- Locale regression: every `lib/**/*.rb` file must not mention `i18n.load_path` / `I18n.load_path`.
- Render-level asserts for overview action names, empty trash, retention settings, restore flash, and settings-updated flash.

### Changed

- Controller flashes, confirm prompts, retention labels, authorize/purge errors, and purge summary messages pass English `default:` on every `Copy.t` call.
- Retention `errors.add(:purge_after_days, ...)` keeps the former English String as the error type (ActiveModel 8.1 ignores `message:` for Strings). In non-English locales, `errors.details` carries the translated string for that former String type.

### Upgrade Notes

- Bump to `0.8.0`. No migration.
- English hosts need no change. Copy `recording_studio.trashable.actions.settings`, `actions.trash_bin`, and any newly defaulted flash/error keys into host locale files when translating.
- Hosts override by defining the same nested keys in their own `config/locales`.
- Metrics DSL titles and descriptions stay English (captured at registration).
- Generator CLI text, unknown-filter `ArgumentError`s, icon/style tokens, and stored recording names stay untranslated.

## [0.7.0] - 2026-10-09

Site-wide trash metrics register with Recording Studio Metrics for the operations API.

### Added
- `RecordingStudioTrashable::Metrics.register!` registers a `:trash` resource
  (`blast_radius: :site`) with RecordingStudioMetrics. Metrics:
  `trash.in_trash` (current in-trash total), `trash.in_trash_by_type`
  (current trash grouped by `recordable_type`), and `trash.trashed_over_time`
  (by `trashed_at`). Each is exposed on `:operations` only. `api_authorize`
  uses `RecordingStudioTrashable::Api::Access.can_view?` (AdminRoot `:view`).
- These counts use existing `RecordingStudio::Recording` rows where
  `trashed_at` is present. Purged items vanish, so the numbers are current
  trash and trashed-over-time of still-existing items only. No new tables
  and no extra event logging.
- Runtime dependency `recording_studio_metrics` `~> 0.2` (GitHub tag `v0.2.0`).

### Upgrade Notes
- Install Trashable `0.7.0`. No migration.
- Add `recording_studio_metrics` at tag `v0.2.0`.
- This gem does not call `RecordingStudioMetrics::Api.register!`. The host
  registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

## [0.6.0] - 2026-10-09

### Added
- Engine overview page (`/recording_studio_trashable`) static interface copy uses Rails I18n under `recording_studio.trashable.home.*`. English only in `config/locales/en.yml`.

### Upgrade Notes
- Install Trashable `0.6.0`. No migration.
- No host code change is required for English. To translate or override the overview page, add keys under `recording_studio.trashable.home` in the host's locale files.
- Method names in the overview list (`recording_studio_trashable_trash!` and friends) stay as code tokens and are not translated.

## [0.5.0] - 2026-10-08

### Added
- Customer-facing trash, restore, purge, retention, and flash copy uses Rails I18n under `recording_studio.trashable.*`. The gem ships English only in `config/locales/en.yml`.
- Restore and purge ask for confirmation before they run.
- Dummy demos English and French via Recording Studio Internationalization (dummy Gemfile only) with a language selector in PageNav.

### Changed
- Dummy pins FlatPack `v0.1.209`.
- Dummy `<html>` sets `lang` (and `dir` when Internationalization is loaded).
- Dummy Tailwind scans the installed Flatpack gem (including `/usr/local/lib/ruby/gems`) and writes Bundler `@source` paths before `tailwindcss:build`, so component utilities compile. Dummy layouts also load `flat_pack/application` for kit CSS (`.fp-button`, select, table) after tokens.

### Upgrade Notes
- Install Trashable `0.5.0`. No migration.
- Copy `recording_studio.trashable.*` into host locale files for other languages.
- Do not add `RecordingStudio_Internationalization` as a dependency of this gem. It is optional on the host.
- Helper arguments and host I18n overrides still win over locale defaults. Recording names and type names stay data and are not translated.
- Restore and purge forms now confirm in the current locale. Hosts that override the trash bin view can keep or replace that prompt.

## [0.4.5] - 2026-10-06

### Changed
- Dummy credentials use the shared Recording Studio development master key.

## [0.4.4] - 2026-10-05

### Changed
- Dummy and development bundles pin RecordingStudio `v4.2.2`.

## [0.4.3] - 2026-10-02

### Changed
- Dummy FlatPack pin moved from `v0.1.133` to `v0.1.198`.

## [0.4.2] - 2026-09-30

### Changed
- The trash bin drops the "Recently trashed roots" subtitle. Empty states say "Nothing in the trash." Search still uses "Search trash".
- Trash settings is a cog icon labeled Settings, and search results sit on the page instead of inside a card.
- The dummy retention purge job runs as the seeded system user, and demo links navigate with FlatPack `href`.

### Fixed
- Purge locks the subtree and deletes those locked rows in the same transaction, so a restore that lands after the preflight check is not permanently deleted.
- Retention sweeps use the nearest saved setting inside the scope. A project retention period applies when the sweep starts at the workspace.
- Invalid retention input is rejected instead of being saved as "keep until manually purged".

## [0.4.1] - 2026-09-02

### Added
- Cloud Agent Builds match RecordingStudio_billing v0.9.13.
- `.cursor/install.sh` provisions a cold image. On a warm snapshot it skips apt, ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are already usable. A skippable provision failure does not fail the Build. Fetch-skills always runs last.
- `.cursor/start.sh` starts PostgreSQL on each boot.

### Upgrade Notes
- No host or schema changes. Product trash and restore are unchanged. Rebuild the Cloud Agent environment with Draft off so Build loads the pack.

## [0.4.0] - 2026-08-21

### Added
- `RecordingStudio::Capabilities::Trashable.to` now wraps core's `RecordingStudio::Capabilities.include_for(:trashable, **options)` factory

### Changed
- Runtime dependency is now RecordingStudio `~> 4.2` (tested with `4.2.0`)
- Dummy and development bundles pin RecordingStudio `v4.2.0`
- Dropped the anonymous-Concern `enable_capability` boilerplate from `.to`

### Upgrade Notes
- Host apps must move to RecordingStudio `~> 4.2` with this gem. Stay on `0.3.x` if you are still on RecordingStudio `4.1.x`.
- Host enablement is unchanged: include `RecordingStudio::Capabilities::Trashable.to(**opts)` on each recordable type that should be trashable. Installing this gem still does not enable the capability.
- Option validation stays in this gem. `register_capability` still runs at boot and is not inside `.to`.

## [0.3.0] - 2026-08-20

### Changed
- Runtime dependency is now RecordingStudio `~> 4.1` (tested with `4.1.0`)
- Dummy and development bundles pin RecordingStudio `v4.1.0` and FlatPack `v0.1.133`
- Dummy app installs the RecordingStudio 4 harden / unique-root indexes
- Dummy and mounted views follow FlatPack `0.1.133` APIs (purge buttons `style: :danger`)
- Dummy and mounted screens use Recording Studio core's default layout (`UsesDefaultLayout` / PageNav back and close) instead of a custom sidebar or breadcrumb shell
- Dummy sign-in is a constrained Flatpack card; Tailwind loads before Flatpack tokens, and `flat_pack/application` is no longer linked (Propshaft does not rewrite its relative imports)
- Dummy docs pages add vertical gap between sections

### Upgrade Notes
- Host apps must move to RecordingStudio `~> 4.1` with this gem. Stay on `0.2.x` if you are still on RecordingStudio 3.
- Run `bin/rails generate recording_studio:migrations` and `bin/rails db:migrate` so the 4.0 harden / unique-root indexes are installed. Resolve duplicate root recordings before the unique index is created.
- Follow RecordingStudio 4.0 upgrade notes for implicit recording order (use `.recent` or an explicit `order:`) and append-only events.
- Prefer `config.require_actor = true` (and optionally `authorize_write` / `max_metadata_bytes`) in production hosts.
- Trashable capability enablement is unchanged: host recordables still opt in with `RecordingStudio::Capabilities::Trashable.to(...)`.
- If you use Recording Studio Accessible 0.6+, configure `config.access_actor_types` and create grants with `RecordingStudioAccessible.grant_access`. Trashable still delegates authorization to Accessible when that addon is loaded.
- Mounted trashable screens now include `RecordingStudio::UsesDefaultLayout` instead of `layout "recording_studio_trashable/application"`. Hosts that overrode that namespaced layout should include `RecordingStudio::UsesDefaultLayout` or set `layout "recording_studio/default_layout"` and use `recording_studio_page_nav` for back/close.

## [0.2.0] - 2026-06-05

### Breaking
- Require `recording_studio ~> 3.0`; host applications must use RecordingStudio 3.x recordable declarations and can no longer rely on the removed core `RecordingStudio::Services::AccessCheck` fallback

### Changed
- Added `trash_root` tracking to recording trash state so trash bins only list explicit trash roots and restores leave nested explicit trash branches in place
- Updated the dummy app recordables, seeds, and documentation for RecordingStudio 3.0 compatibility
- Retention purges now skip a parent until every trashed descendant in that subtree is also retention-due, preventing partial subtree purges

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.3.1...HEAD
[1.3.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.2.3...v1.3.0
[1.2.3]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.17.0...v1.0.0
[0.17.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.16.1...v0.17.0
[0.16.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.16.0...v0.16.1
[0.16.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.14.1...v0.15.0
[0.14.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.12.3...v0.13.0
[0.12.3]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.12.2...v0.12.3
[0.12.2]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.12.1...v0.12.2
[0.12.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.11.3...v0.12.0
[0.11.3]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.11.2...v0.11.3
[0.11.2]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.11.1...v0.11.2
[0.11.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.10.1...v0.11.0
[0.10.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.5...v0.5.0
[0.4.5]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.4...v0.4.5
[0.4.4]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/releases/tag/v0.2.0
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/releases/tag/v0.1.0
