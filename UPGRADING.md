# Upgrading

## 1.2.2

Bump to 1.2.2. No host action is needed. No migration.

Hosts that eager-load `controllers/` still get the trash bin live search controller. Lazy-load hosts fetch it on first use. Landing pages no longer modulepreload that controller.

## 1.0.0

Install `recording_studio_trashable` 1.0.0. No migration. There is no alias and no compatibility shim.

`RecordingStudioTrashable::Hooks` and `RecordingStudioTrashable.configuration.hooks` are gone. `configuration.to_h` no longer includes `:hooks_registered`. The engine no longer runs `:before_initialize`, `:on_configuration`, or `:after_initialize`.

Register those hooks on `RecordingStudio.configuration.hooks`. Core runs that registry. This gem does not call it during boot.

Trash, restore, purge, trashed rows, and `purge_at` are unchanged. The query entry point is unchanged. Sibling gemspecs that only need it should depend on `~> 1.0`.

Accessible `v0.45.0` requires `recording_studio_trashable >= 0.17.0, < 1.0`. Admin `v2.16.0` requires `>= 0.16.1, < 1.0`. A host that installs either of those releases cannot bundle Trashable `1.0.0`. Those gemspecs have to allow `1.0` before this release can be installed beside them. There is no Bundler override in this gem.
