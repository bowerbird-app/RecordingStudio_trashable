# frozen_string_literal: true

require "recording_studio_trashable/subtree_query"

module RecordingStudioTrashable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioTrashable

    config.to_prepare do
      next unless defined?(RecordingStudio::Recording)

      RecordingStudio.apply_capabilities!
      unless RecordingStudio::Recording.included_modules.include?(RecordingStudioTrashable::RecordingScopes)
        RecordingStudio::Recording.include(RecordingStudioTrashable::RecordingScopes)
      end
    end

    initializer "recording_studio_trashable.before_initialize",
                before: "recording_studio_trashable.load_config" do |_app|
      RecordingStudioTrashable::Hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_trashable.load_config" do |app|
      RecordingStudioTrashable::Engine.send(:load_yaml_config, app)
      RecordingStudioTrashable::Engine.send(:load_x_config, app.config.x.recording_studio_trashable) if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_trashable)
      RecordingStudioTrashable::Hooks.run(:on_configuration, RecordingStudioTrashable.configuration)
    end

    initializer "recording_studio_trashable.after_initialize",
                after: "recording_studio_trashable.load_config" do |_app|
      RecordingStudioTrashable::Hooks.run(:after_initialize, self)
    end

    class << self
      private

      def load_yaml_config(app)
        return unless app.respond_to?(:config_for)

        yaml = app.config_for(:recording_studio_trashable)
        RecordingStudioTrashable.configuration.merge!(yaml) if yaml.respond_to?(:each)
      rescue StandardError => error
        log_configuration_load_error("config_for(:recording_studio_trashable)", error)
      end

      def load_x_config(config)
        values = if config.respond_to?(:to_h)
                   config.to_h
                 elsif config.respond_to?(:each_pair)
                   config.each_pair.each_with_object({}) { |(key, value), result| result[key] = value }
                 else
                   {}
                 end
        RecordingStudioTrashable.configuration.merge!(values) if values.any?
      rescue StandardError => error
        log_configuration_load_error("config.x.recording_studio_trashable", error)
      end

      def log_configuration_load_error(source, error)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.debug { "[RecordingStudioTrashable] Failed to load #{source}: #{error.message}" }
      end
    end
  end
end
