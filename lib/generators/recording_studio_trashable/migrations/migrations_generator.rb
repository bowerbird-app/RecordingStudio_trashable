# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioTrashable
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("../../../..", __dir__)

      desc "Copy RecordingStudioTrashable migrations to your application"

      class_option :skip_existing,
                   type: :boolean,
                   default: true,
                   desc: "Skip migrations that already exist (based on name, ignoring timestamp)"

      def copy_migrations
        migrations_dir = File.join(self.class.source_root, "db", "migrate")
        migration_files = Dir.glob(File.join(migrations_dir, "*.rb"))
        return say("No migrations found in RecordingStudioTrashable.", :yellow) if migration_files.empty?

        migration_files.each do |source_path|
          migration_name = File.basename(source_path).sub(/^\d+_/, "")
          if options[:skip_existing] && migration_exists?(migration_name)
            say "  skip  #{migration_name} (already exists)", :yellow
            next
          end

          destination_path = File.join("db/migrate", "#{next_migration_number}_#{migration_name}")
          copy_file source_path, destination_path
          sleep 0.1
        end
      end

      private

      def migration_exists?(migration_name)
        Dir.glob(File.join(destination_root, "db/migrate", "*_#{migration_name}")).any?
      end

      def next_migration_number
        ActiveRecord::Migration.next_migration_number(Time.now.utc.strftime("%Y%m%d%H%M%S"))
      end
    end
  end
end
