# frozen_string_literal: true

require_relative "../../test_helper"
require "yaml"
require "active_support/encrypted_file"

class CredentialsTest < Minitest::Test
  PLACEHOLDER = "dev_placeholder"

  def test_dummy_credentials_expose_shared_keys_when_the_master_key_is_available
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    credentials = decrypted_credentials
    assert credentials.fetch("secret_key_base").to_s.present?
    assert_equal PLACEHOLDER, credentials.dig("gem_template", "api_key")
    assert_equal PLACEHOLDER, credentials.dig("smtp", "user_name")
    assert_equal PLACEHOLDER, credentials.dig("smtp", "password")
    assert_equal PLACEHOLDER, credentials.dig("aws", "access_key_id")
    assert_equal PLACEHOLDER, credentials.dig("aws", "secret_access_key")
  end

  private

  def decrypted_credentials
    YAML.safe_load(
      ActiveSupport::EncryptedFile.new(
        content_path: File.expand_path("../config/credentials.yml.enc", __dir__),
        key_path: File.expand_path("../config/master.key", __dir__),
        env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true
      ).read
    )
  end

  def master_key_available?
    ENV["RAILS_MASTER_KEY"].to_s.strip.present? || File.exist?(File.expand_path("../config/master.key", __dir__))
  end
end
