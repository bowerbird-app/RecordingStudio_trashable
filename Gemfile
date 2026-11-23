# frozen_string_literal: true

source "https://rubygems.org"

gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"
# Named MCP tools. Not a gemspec dependency: MCP depends on Oauth, and Oauth depends on this gem.
gem "recording_studio_accessible", "~> 0.58", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"
gem "recording_studio_admin", "~> 2.20", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.20.0"
gem "recording_studio_api", "~> 1.21", github: "bowerbird-app/RecordingStudio_api", tag: "v1.21.3"
gem "recording_studio_attachable", "~> 0.34", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.34.4"
gem "recording_studio_cache", "~> 0.8", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"
gem "recording_studio_icons", "~> 0.5", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0"
gem "recording_studio_logs", "~> 0.9", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"
gem "recording_studio_mcp", ">= 0.45", "< 0.46", github: "bowerbird-app/RecordingStudio_MCP", tag: "v0.45.2"
gem "recording_studio_moveable", "~> 6.1", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0"
gem "recording_studio_oauth", github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.25.1"
gem "recording_studio_site_settings", github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.6.0"
gem "view_component", "4.19.0"

gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "pg"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
