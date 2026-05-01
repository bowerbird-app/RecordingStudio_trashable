# frozen_string_literal: true

RecordingStudioTrashable.configure do |config|
  # Keep Accessible integration enabled when the addon is installed.
  config.use_recording_studio_accessible = true

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

  # Opt in if subtree admins should be allowed to override retention timing in the mounted UI.
  config.allow_user_retention_settings = false

  # Resolve a system actor for scheduled retention purges when purge authorization needs one.
  # config.retention_purge_actor_resolver = -> { User.find_by!(email: "system@example.com") }

  # Override either resolver if your host app does not use Current.actor / Current.impersonator.
  # config.current_actor_resolver = ->(controller:) { controller.current_user }
  # config.authorization_resolver = ->(action:, actor:, recording:, **) { true }
end
