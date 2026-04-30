# frozen_string_literal: true

RecordingStudioTrashable.configure do |config|
  # Keep Accessible integration enabled when the addon is installed.
  config.accessible_integration_enabled = true

  # Defaults: trash/edit, restore/edit, purge/admin, settings/admin
  config.authorization_roles = {
    trash: :edit,
    restore: :edit,
    purge: :admin,
    settings: :admin,
    trash_bin: :edit
  }

  # Optional subtree-level default when no retention setting record exists.
  config.default_purge_after_days = nil

  # Override either resolver if your host app does not use Current.actor / Current.impersonator.
  # config.current_actor_resolver = ->(controller:) { controller.current_user }
  # config.authorization_resolver = ->(action:, actor:, recording:, **) { true }
end
