# frozen_string_literal: true

source "https://rubygems.org"

gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v0.1.0-alpha"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.33"

gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
