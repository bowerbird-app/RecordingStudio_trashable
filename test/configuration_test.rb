# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioTrashable::Configuration.new
  end

  def test_merge_updates_known_attributes_and_roles
    @configuration.merge!(
      use_recording_studio_accessible: false,
      allow_unconfigured_authorization: true,
      default_purge_after_days: 21,
      allow_user_retention_settings: true,
      authorization_roles: { purge: :edit }
    )

    assert_equal false, @configuration.use_recording_studio_accessible
    assert_equal true, @configuration.allow_unconfigured_authorization
    assert_equal 21, @configuration.default_purge_after_days
    assert_equal true, @configuration.allow_user_retention_settings
    assert_equal :edit, @configuration.role_for(:purge)
    assert_equal :edit, @configuration.role_for(:trash)
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", hooks: "nope")

    refute_respond_to @configuration, :unknown_key
    refute_respond_to @configuration, :hooks
    assert_equal true, @configuration.use_recording_studio_accessible
  end

  def test_to_h_omits_the_removed_hook_registry
    result = @configuration.to_h

    assert_equal false, result.fetch(:allow_user_retention_settings)
    assert_equal false, result.fetch(:allow_unconfigured_authorization)
    assert_nil result.fetch(:retention_purge_actor_resolver)
    assert_nil result.fetch(:retention_purge_impersonator_resolver)
    refute result.key?(:hooks_registered)
    refute_respond_to @configuration, :hooks
  end
end
