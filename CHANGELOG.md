# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0](https://github.com/bowerbird-app/RecordingStudio_trashable/compare/recording_studio_trashable-v0.1.1...recording_studio_trashable/v1.0.0) (2026-09-02)


### ⚠ BREAKING CHANGES

* recording_studio_trashable now requires RecordingStudio 3.x recordable declarations and no longer supports the removed core AccessCheck fallback.

### Features

* add trashable defaults and retention purger ([2847c85](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/2847c8564443cf6c68c3f9a0015e8ca19895188d))
* **cursor:** add Billing 0.9.13 Cloud Agent boot ([#6](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/6)) ([2a7abd6](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/2a7abd69e0569d0144424cb129959b716e0f3d71))
* require RecordingStudio 3.0 ([e0abfae](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/e0abfae7e55be7aec0524ef1a0bb026faff2ba94))
* tighten trash auth and retention flows ([577d9af](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/577d9af3826726e3c5502cccb4c0512b88f763f3))
* wrap trashable enablement with core 4.2 include_for factory ([#5](https://github.com/bowerbird-app/RecordingStudio_trashable/issues/5)) ([1e1c0f7](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/1e1c0f7f3b4f418f3015ec78769aacb8024c2ed8))


### Bug Fixes

* restore dummy app engine pages ([61342d7](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/61342d732fbae4191f2e72257c85e3662d993264))
* tighten mounted auth and retention semantics ([490a7c4](https://github.com/bowerbird-app/RecordingStudio_trashable/commit/490a7c435f510bf9a5884f23fe3c06466b14cce7))

## [Unreleased]

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.1...HEAD
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/releases/tag/v0.2.0
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_trashable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_trashable/releases/tag/v0.1.0
