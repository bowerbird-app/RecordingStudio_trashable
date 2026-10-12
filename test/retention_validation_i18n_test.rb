# frozen_string_literal: true

require "test_helper"
require "active_model"

# Error-type fidelity for former English-string validation types (Marshal/Han):
# ActiveModel 8.1 ignores message: when the type is a String, so Copy.t is the type.
class RetentionValidationI18nTest < Minitest::Test
  ENGLISH = "must be a positive whole number"
  HOST_ENGLISH = "HOST must be a positive whole number"
  FRENCH = "doit être un nombre entier positif"

  class RetentionSettingStub
    extend ActiveModel::Naming
    include ActiveModel::Translation

    def self.human_attribute_name(attribute, _options = {})
      attribute.to_s.humanize
    end
  end

  def setup
    @previous_load_path = I18n.load_path.dup
    @previous_backend = I18n.backend
    @previous_locale = I18n.locale
    @previous_available = I18n.available_locales
    I18n.available_locales = Array(@previous_available) | %i[en fr]
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations(*Dir[File.expand_path("../config/locales/*.yml", __dir__)])
    I18n.locale = :en
  end

  def teardown
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    I18n.available_locales = @previous_available
    assert_equal @previous_load_path, I18n.load_path,
                 "validation i18n tests must not mutate I18n.load_path"
  end

  def test_english_error_details_match_main_string_types
    errors = add_purge_after_days_invalid

    reference = ActiveModel::Errors.new(RetentionSettingStub.new)
    reference.add(:purge_after_days, ENGLISH)

    assert_equal reference.details[:purge_after_days], errors.details[:purge_after_days]
    assert_equal [{ error: ENGLISH }], errors.details[:purge_after_days]
    assert_includes errors.full_messages.join, ENGLISH
  end

  def test_french_full_messages_use_translated_string_type
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        trashable: {
          errors: { purge_after_days_invalid: FRENCH }
        }
      }
    )

    I18n.with_locale(:fr) do
      errors = add_purge_after_days_invalid

      assert_equal [{ error: FRENCH }], errors.details[:purge_after_days]
      assert_includes errors.full_messages.join, FRENCH
      refute_includes errors.full_messages.join, ENGLISH
    end
  end

  def test_host_override_wins_for_validation_string_types
    host = File.expand_path("dummy/test/locales/trashable_host_override.en.yml", __dir__)
    assert File.exist?(host), "expected test-only host override fixture at #{host}"

    I18n.t("recording_studio.trashable.errors.purge_after_days_invalid")
    I18n.backend.load_translations(host)

    errors = add_purge_after_days_invalid

    assert_equal [{ error: HOST_ENGLISH }], errors.details[:purge_after_days]
    assert_includes errors.full_messages.join, HOST_ENGLISH
    assert_equal @previous_load_path, I18n.load_path
  end

  private

  def add_purge_after_days_invalid
    errors = ActiveModel::Errors.new(RetentionSettingStub.new)
    errors.add(
      :purge_after_days,
      RecordingStudioTrashable::Copy.t(
        "errors.purge_after_days_invalid",
        default: ENGLISH
      )
    )
    errors
  end
end
