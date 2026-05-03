# frozen_string_literal: true

require "recording_studio_trashable/subtree_query"

module RecordingStudioTrashable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioTrashable

    initializer "recording_studio_trashable.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << Engine.root.join("config/importmap.rb")
      app.config.assets.paths << Engine.root.join("app/javascript")
    end

    config.to_prepare do
      RecordingStudioTrashable.install_recording_capabilities!
    end

    initializer "recording_studio_trashable.before_initialize",
                before: "recording_studio_trashable.load_config" do |_app|
      RecordingStudioTrashable::Hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_trashable.load_config" do |app|
      RecordingStudioTrashable::Engine.send(:load_yaml_config, app)
      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_trashable)
        RecordingStudioTrashable::Engine.send(:load_x_config,
                                              app.config.x.recording_studio_trashable)
      end
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
      rescue StandardError => e
        log_configuration_load_error("config_for(:recording_studio_trashable)", e)
      end

      def load_x_config(config)
        values = if config.respond_to?(:to_h)
                   config.to_h
                 elsif config.respond_to?(:each_pair)
                   config.each_pair.with_object({}) { |(key, value), result| result[key] = value }
                 else
                   {}
                 end
        RecordingStudioTrashable.configuration.merge!(values) if values.any?
      rescue StandardError => e
        log_configuration_load_error("config.x.recording_studio_trashable", e)
      end

      def log_configuration_load_error(source, error)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.debug { "[RecordingStudioTrashable] Failed to load #{source}: #{error.message}" }
      end
    end
  end
end
