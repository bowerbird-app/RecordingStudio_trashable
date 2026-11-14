# frozen_string_literal: true

# Pinned sibling gems still call this class method. The gem no longer defines it.
Rails.application.reloader.to_prepare do
  RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_kept_sql) do |table = "recording_studio_recordings"|
    RecordingStudio.kept_sql(table)
  end
end

RecordingStudioTrashable.configure do |config|
  config.default_purge_after_days = 30
  config.allow_user_retention_settings = true
  config.authorization_resolver = ->(action:, actor:, **) { action.present? && actor.present? }
  config.retention_purge_actor_resolver = -> { User.find_by!(email: "system@example.com") }
end
