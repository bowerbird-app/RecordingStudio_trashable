# frozen_string_literal: true

require_relative "lib/recording_studio_trashable/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_trashable"
  spec.version     = RecordingStudioTrashable::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_trashable"
  spec.summary     = "Trash and retention addon for RecordingStudio"
  spec.description =
    "Recording Studio Trashable extracts trash bin, restore, purge, retention, and mounted UI " \
    "behavior into an opt-in Rails engine addon."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_trashable"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_trashable/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "flat_pack", ">= 0.1.74"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.1"
end
