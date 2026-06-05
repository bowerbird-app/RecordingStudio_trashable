# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "active_support/core_ext/time"
require "active_support/core_ext/integer/time"
require "recording_studio_trashable"

class Object
  def stub(method_name, replacement, *stub_args, **stub_kwargs)
    singleton = class << self; self; end
    original_method = :"__copilot_stub_original_#{method_name}"
    method_defined = singleton.method_defined?(method_name) || singleton.private_method_defined?(method_name)

    singleton.alias_method(original_method, method_name) if method_defined

    singleton.define_method(method_name) do |*args, **kwargs, &block|
      if replacement.respond_to?(:call)
        replacement.call(*args, *stub_args, **kwargs, **stub_kwargs, &block)
      else
        block&.call(*stub_args, **stub_kwargs)
        replacement
      end
    end

    yield self
  ensure
    singleton.send(:remove_method, method_name) if singleton.method_defined?(method_name)

    if method_defined
      singleton.alias_method(method_name, original_method)
      singleton.send(:remove_method, original_method)
    end
  end
end
