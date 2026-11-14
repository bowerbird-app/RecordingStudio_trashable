# frozen_string_literal: true

source "https://rubygems.org"

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.374"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.13.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.8.0"
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
