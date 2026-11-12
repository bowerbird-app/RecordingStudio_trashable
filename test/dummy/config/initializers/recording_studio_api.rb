# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.configure do |config|
  config.documentation_enabled = true
  config.documentation_access = :public
  config.openapi_title = "Trashable API"
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_management_authorization_required = false
end

RecordingStudioApi.register_recordable_type_api(
  "Page",
  operations: %i[show],
  serializer: ->(page, **) { { title: page.title, slug: page.slug } },
  output_keys: %i[title slug]
)
