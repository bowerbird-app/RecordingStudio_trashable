# frozen_string_literal: true

module RecordingStudioTrashable
  class Hooks
    class HookError < StandardError; end

    DEFAULT_PRIORITY = 100

    attr_accessor :raise_on_error

    def initialize
      @registry = Hash.new { |hash, key| hash[key] = [] }
      @raise_on_error = false
      @mutex = Mutex.new
    end

    def before_initialize(handler = nil, priority: DEFAULT_PRIORITY, &block)
      register(:before_initialize, handler, priority: priority, &block)
    end

    def after_initialize(handler = nil, priority: DEFAULT_PRIORITY, &block)
      register(:after_initialize, handler, priority: priority, &block)
    end

    def on_configuration(handler = nil, priority: DEFAULT_PRIORITY, &block)
      register(:on_configuration, handler, priority: priority, &block)
    end

    def on(event_name, handler = nil, priority: DEFAULT_PRIORITY, &block)
      register(event_name, handler, priority: priority, &block)
    end

    def run(event_name, *args)
      @registry[event_name].sort_by { |hook| hook[:priority] }.map do |hook|
        execute_hook(hook[:handler], *args)
      rescue StandardError => error
        handle_hook_error(error, event_name)
      end
    end

    def registered?(event_name)
      @registry[event_name].any?
    end

    def clear!(event_name = nil)
      @mutex.synchronize do
        event_name ? @registry.delete(event_name) : @registry.clear
      end
    end

    private

    def register(event_name, handler, priority:, &block)
      callable = handler || block
      return unless callable

      @mutex.synchronize do
        @registry[event_name] << { handler: callable, priority: priority }
      end
    end

    def execute_hook(handler, *args)
      handler.call(*args)
    end

    def handle_hook_error(error, event_name)
      raise HookError, "Hook failed for #{event_name}: #{error.message}" if raise_on_error

      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      Rails.logger.error("[RecordingStudioTrashable::Hooks] Error in #{event_name}: #{error.message}")
    end

    class << self
      def run(event_name, *args)
        RecordingStudioTrashable.configuration.hooks.run(event_name, *args)
      end
    end
  end
end
