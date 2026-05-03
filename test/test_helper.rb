# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "active_support/core_ext/time"
require "active_support/core_ext/integer/time"
require "recording_studio_trashable"
