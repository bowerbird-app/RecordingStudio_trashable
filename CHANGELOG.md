# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0](https://github.com/bowerbird-app/RecordingStudio_trashable/compare/recording_studio_trashable-v0.1.1...recording_studio_trashable/v1.0.0) (2026-10-28)


### ⚠ BREAKING CHANGES

* adopt Recording Studio 6.1 layout and Flatpack 0.1.319 ([#26](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/26))
* recording_studio_trashable now requires RecordingStudio 3.x recordable declarations and no longer supports the removed core AccessCheck fallback.

### Features

* add trashable defaults and retention purger ([2847c85](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/2847c8564443cf6c68c3f9a0015e8ca19895188d))
* adopt Recording Studio 6.1 layout and Flatpack 0.1.319 ([#26](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/26)) ([ca6b9e6](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/ca6b9e6bd907a6fcf79552e4fb36ca0137d23eeb))
* **cursor:** add Billing 0.9.13 Cloud Agent boot ([#6](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/6)) ([2a7abd6](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/2a7abd69e0569d0144424cb129959b716e0f3d71))
* require RecordingStudio 3.0 ([e0abfae](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/e0abfae7e55be7aec0524ef1a0bb026faff2ba94))
* tighten trash auth and retention flows ([577d9af](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/577d9af3826726e3c5502cccb4c0512b88f763f3))
* wrap trashable enablement with core 4.2 include_for factory ([#5](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/5)) ([1e1c0f7](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/1e1c0f7f3b4f418f3015ec78769aacb8024c2ed8))


### Bug Fixes

* restore dummy app engine pages ([61342d7](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/61342d732fbae4191f2e72257c85e3662d993264))
* tighten mounted auth and retention semantics ([490a7c4](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/490a7c435f510bf9a5884f23fe3c06466b14cce7))

## [Unreleased]

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.12.1...HEAD
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
