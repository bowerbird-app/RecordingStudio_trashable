# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioTrashable::Configuration.new
  end

  def test_merge_updates_known_attributes_and_roles
    @configuration.merge!(
      accessible_integration_enabled: false,
      default_purge_after_days: 21,
      authorization_roles: { purge: :edit }
    )

    assert_equal false, @configuration.accessible_integration_enabled
    assert_equal 21, @configuration.default_purge_after_days
    assert_equal :edit, @configuration.role_for(:purge)
    assert_equal :edit, @configuration.role_for(:trash)
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored")

    refute_respond_to @configuration, :unknown_key
    assert_equal true, @configuration.accessible_integration_enabled
  end

  def test_to_h_reports_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_initialize { nil }

    result = @configuration.to_h

    assert_equal 1, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_initialize)
  end
end
