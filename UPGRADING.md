# Upgrading

## 1.3.2

Install `recording_studio_trashable` 1.3.2. No migration. No host action when Recording Studio MCP is not loaded.

Hosts that load Recording Studio MCP 0.45 or newer get one named tool per trashable type on the next boot. A page gets `trash_page`, `restore_page`, `purge_page`, and `list_pages_trash_bin`. Trash, restore, and purge stay singular. The trash bin tool pluralizes the snake public name, so a press center gets `list_press_centers_trash_bin`. Add `recording_studio_mcp`, `>= 0.45`, `< 0.46`, to the app Gemfile to load MCP. This gem does not require it.

Set `public_name` on an API type only when two trashable types would share one snake_case tool name.

OpenAPI descriptions for these actions now describe the endpoint, the subtree, and the 404 and 422 cases. MCP tool descriptions are unchanged. An `override_openapi` description changes the OpenAPI document only. A title override still changes the MCP tool title.

## 1.3.1

Install `recording_studio_trashable` 1.3.1. No migration. No host action unless a caller rescued `ArgumentError` when trash, restore, or purge was denied. Rescue `RecordingStudio::AuthorizationError` for that denial. Argument bugs still raise `ArgumentError`. API still returns forbidden. Mounted UI still shows the not-authorized message.

## 1.3.0

Install `recording_studio_trashable` 1.3.0. No Trashable migration. The gemspec still requires `recording_studio >= 7.0`, `< 8.0`, `flat_pack >= 0.1.315`, and `recording_studio_metrics >= 0.3.0`, `< 1.0`.

Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not. The dummy app does not copy those three.

Development Gemfiles pin Recording Studio `v7.8.0` (`~> 7.8`), FlatPack `v0.2.0` (`~> 0.2`), and Metrics `v0.10.0` (`~> 0.10`). The dummy also pins Accessible `v0.56.0`, API `v1.19.0`, Admin `v2.19.1`, Logs `v0.8.2`, Moveable `v6.0.3`, Icons `v0.5.0`, and Internationalization `v0.3.1`.

flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration. Hosts that stay on FlatPack 0.1.x still resolve.

## 1.2.3

Install `recording_studio_trashable` 1.2.3. No Trashable migration. The gemspec still requires `recording_studio >= 7.0`, `< 8.0` and `recording_studio_metrics >= 0.3.0`, `< 1.0`.

Hosts moving to Recording Studio 7.7 must run the Recording Studio 7.4, 7.5, and 7.7 migrations. The dummy app does not copy those three.

Development Gemfiles pin Recording Studio `v7.7.1`, FlatPack `v0.1.378`, and Metrics `v0.9.2`. The dummy also pins Accessible `v0.54.1`, API `v1.16.0`, Admin `v2.19.0`, Logs `v0.8.1`, Moveable `v6.0.2`, Icons `v0.4.2`, and Internationalization `v0.3.1`.

A host that mounts Recording Studio API 1.12 or newer needs `config/recording_studio_api.yml`. `shared: {}` is enough. Copy API migration `20261117000024_add_owner_to_recording_studio_api_api_clients` before `ProvisionApiClient` writes `owner`. The dummy copies that migration. It does not add Accessible access-request migrations.

## 1.2.2

Bump to 1.2.2. No host action is needed. No migration.

Hosts that eager-load `controllers/` still get the trash bin live search controller. Lazy-load hosts fetch it on first use. Landing pages no longer modulepreload that controller.

## 1.0.0

Install `recording_studio_trashable` 1.0.0. No migration. There is no alias and no compatibility shim.

`RecordingStudioTrashable::Hooks` and `RecordingStudioTrashable.configuration.hooks` are gone. `configuration.to_h` no longer includes `:hooks_registered`. The engine no longer runs `:before_initialize`, `:on_configuration`, or `:after_initialize`.

Register those hooks on `RecordingStudio.configuration.hooks`. Core runs that registry. This gem does not call it during boot.

Trash, restore, purge, trashed rows, and `purge_at` are unchanged. The query entry point is unchanged. Sibling gemspecs that only need it should depend on `~> 1.0`.

Accessible `v0.45.0` requires `recording_studio_trashable >= 0.17.0, < 1.0`. Admin `v2.16.0` requires `>= 0.16.1, < 1.0`. A host that installs either of those releases cannot bundle Trashable `1.0.0`. Those gemspecs have to allow `1.0` before this release can be installed beside them. There is no Bundler override in this gem.
