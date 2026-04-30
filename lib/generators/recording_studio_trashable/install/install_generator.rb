# frozen_string_literal: true

require "rails/generators"

module RecordingStudioTrashable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioTrashable into your application"

      class_option :mount_path,
                   type: :string,
                   default: "/recording_studio_trashable",
                   desc: "Route prefix used when mounting the engine"

      def mount_engine
        route %(mount RecordingStudioTrashable::Engine, at: "#{options[:mount_path]}")
      end

      def copy_initializer
        template "recording_studio_trashable_initializer.rb", "config/initializers/recording_studio_trashable.rb"
      end

      def add_tailwind_source
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        return unless File.exist?(tailwind_css_path)

        tailwind_content = File.read(tailwind_css_path)
        missing_lines = tailwind_source_lines.reject { |line| tailwind_content.include?(line) }
        return if missing_lines.empty?

        inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
          "\n/* Include RecordingStudioTrashable engine views for Tailwind CSS */\n#{missing_lines.join("\n")}\n"
        end
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def tailwind_source_lines
        [
          '@source "../../vendor/bundle/**/recording_studio_trashable/app/views/**/*.erb";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/recording_studio_trashable-*/app/views/**/*.erb";',
          '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
        ]
      end
    end
  end
end
