# frozen_string_literal: true

require "test_helper"

class TailwindBuildTest < ActiveSupport::TestCase
  test "compiled tailwind includes Flatpack component utilities" do
    css_path = Rails.root.join("app/assets/builds/tailwind.css")
    sources_path = Rails.root.join("app/assets/builds/tailwind/gem_sources.css")

    assert File.exist?(sources_path), "expected rake tailwindcss:gem_sources to write Bundler @source paths"
    sources = File.read(sources_path)
    assert_includes sources, "app/components/**/*.rb"
    assert_match %r{/bundler/gems/flatpack-}, sources

    assert File.exist?(css_path), "expected bin/rails tailwindcss:build to write tailwind.css"
    css = File.read(css_path)
    assert_includes css, "flat-pack-select"
    assert_includes css, "flat-pack-input-wrapper"
    assert_includes css, "button-border-radius"
  end
end
