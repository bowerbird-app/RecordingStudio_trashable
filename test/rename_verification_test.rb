# frozen_string_literal: true

require "yaml"
require_relative "simplecov_helper"
require "minitest/autorun"

class RenameVerificationTest < Minitest::Test
  def setup
    @root = File.expand_path("..", __dir__)
    @gem_name = detect_gem_name
    @pascal_name = to_pascal_case(@gem_name)
  end

  def test_gemspec_file_exists
    assert File.exist?(File.join(@root, "#{@gem_name}.gemspec"))
  end

  def test_main_lib_file_exists
    assert File.exist?(File.join(@root, "lib", "#{@gem_name}.rb"))
  end

  def test_engine_file_exists
    assert File.exist?(File.join(@root, "lib", @gem_name, "engine.rb"))
  end

  def test_routes_reference_correct_engine
    content = File.read(File.join(@root, "config", "routes.rb"))

    assert_match(/#{@pascal_name}::Engine\.routes\.draw/, content)
  end

  def test_no_old_template_ruby_references_remain_outside_docs_and_dummy
    ruby_files = Dir.glob(File.join(@root, "**", "*.rb"))
    ruby_files.reject! { |path| path.include?("docs/") || path.include?("test/dummy") || path.include?("rename_verification_test.rb") }

    offenders = ruby_files.select do |path|
      content = File.read(path)
      content.include?("gem_template") || content.include?("GemTemplate")
    end

    assert offenders.empty?, "Found old template references in:
#{offenders.join("
")}"
  end

  private

  def detect_gem_name
    gemspec_files = Dir.glob(File.join(@root, "*.gemspec"))
    File.basename(gemspec_files.first, ".gemspec")
  end

  def to_pascal_case(value)
    value.split("_").map(&:capitalize).join
  end
end
