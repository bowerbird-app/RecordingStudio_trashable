# frozen_string_literal: true

RecordingStudioTrashable.configure do |config|
  config.default_purge_after_days = 30
  config.allow_user_retention_settings = true
end
