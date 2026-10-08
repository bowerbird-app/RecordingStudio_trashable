# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  Copy = RecordingStudioTrashable::Copy

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "Trash", Copy.t("trash.title")
      assert_equal "Close", Copy.t("trash.close")
      assert_equal "Settings", Copy.t("trash.settings")
      assert_equal "Search trash", Copy.t("trash.search_placeholder")
      assert_equal "Nothing in the trash.", Copy.t("trash.empty")
      assert_equal "Nothing in the trash matches your search.", Copy.t("trash.empty_search")
      assert_equal "Restore", Copy.t("trash.restore")
      assert_equal "Purge", Copy.t("trash.purge")
      assert_equal "Name", Copy.t("trash.columns.name")
      assert_equal "Type", Copy.t("trash.columns.type")
      assert_equal "Trashed", Copy.t("trash.columns.trashed")
      assert_equal "Action", Copy.t("trash.columns.action")
      assert_equal "Restore Mix Notes?", Copy.t("confirms.restore", name: "Mix Notes")
      assert_equal "Permanently delete Mix Notes?", Copy.t("confirms.purge", name: "Mix Notes")
      assert_equal "Mix Notes moved to trash", Copy.t("flashes.trashed", name: "Mix Notes")
      assert_equal "Mix Notes restored", Copy.t("flashes.restored", name: "Mix Notes")
      assert_equal "Mix Notes permanently deleted", Copy.t("flashes.purged", name: "Mix Notes")
      assert_equal "Trash settings updated.", Copy.t("flashes.settings_updated")
      assert_equal "You are not authorized to manage trash here.", Copy.t("flashes.unauthorized")
      assert_equal "Retention settings are managed by the application.", Copy.t("flashes.retention_managed")
      assert_equal "Not authorized to trash Page", Copy.t("errors.not_authorized", action: "trash", type: "Page")
      assert_equal "Purging requires all targeted recordings to already be trashed", Copy.t("errors.purge_not_trashed")
      assert_equal "must be a positive whole number", Copy.t("errors.purge_after_days_invalid")
      assert_equal "Could not save retention settings", Copy.t("errors.could_not_save_retention")
      assert_equal "Retention period", Copy.t("retention.title")
      assert_equal "Number of days to keep trashed items.", Copy.t("retention.subtitle")
      assert_equal "Keep until manually purged", Copy.t("retention.keep_until_purged")
      assert_equal "7 days", Copy.t("retention.days", count: 7)
      assert_equal "1 day", Copy.t("retention.days", count: 1)
      assert_equal "No automatic purge window", Copy.t("retention.no_automatic_purge")
      assert_equal "Due now", Copy.t("retention.due_now")
      assert_equal "Purged 1 recording.", Copy.t("summary.purged", count: 1)
      assert_equal "Purged 2 recordings.", Copy.t("summary.purged", count: 2)
      assert_equal "No recordings were purged.", Copy.t("summary.none_purged")
    end
  end

  def test_component_text_overrides_win_including_nil
    assert_equal "Trash", Copy.value(Copy::UNSET, "trash.title")
    assert_equal "Acme bin", Copy.value("Acme bin", "trash.title")
    assert_nil Copy.value(nil, "trash.title")
  end

  def test_defaulted_follows_locale_until_the_host_changes_the_string
    I18n.with_locale(:en) do
      assert_equal "Trash", Copy.defaulted("Trash", "Trash", "trash.title")
      assert_equal "Acme bin", Copy.defaulted("Acme bin", "Trash", "trash.title")
      assert_equal "Trash", Copy.defaulted(nil, "Trash", "trash.title")
    end
  end

  def test_host_translation_overrides_english
    I18n.backend.store_translations(:en, acme_title)
    assert_equal "Acme bin", Copy.t("trash.title")
  ensure
    I18n.backend.store_translations(:en, default_title)
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_trashable.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  def test_dummy_gemfile_depends_on_internationalization_and_latest_flatpack
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes dummy_gemfile, "recording_studio_internationalization"
    assert_includes dummy_gemfile, "RecordingStudio_Internationalization"
    assert_includes dummy_gemfile, 'tag: "v0.1.209"'
  end

  def test_config_copy_overrides_still_win_over_locale_defaults
    I18n.with_locale(:en) do
      assert_equal "Host trash", Copy.value("Host trash", "trash.title")
      assert_equal(
        "Keep forever",
        Copy.defaulted("Keep forever", "Keep until manually purged", "retention.keep_until_purged")
      )
    end
  end

  def test_html_copy_escapes_interpolations_and_marks_html_safe
    I18n.backend.store_translations(:en, html_note)

    html = Copy.t("note_html", name: "<script>x</script>")

    assert_predicate html, :html_safe?
    refute_includes html, "<script>"
    assert_includes html, "&lt;script&gt;x&lt;/script&gt;"
    assert_includes html, "<b>"
  ensure
    I18n.backend.store_translations(:en, { recording_studio: { trashable: { note_html: nil } } })
  end

  def test_action_name_uses_locale_and_falls_back_to_the_action
    I18n.with_locale(:en) do
      assert_equal "trash", Copy.action_name(:trash)
      assert_equal "restore", Copy.action_name("restore")
      assert_equal "archive", Copy.action_name(:archive)
    end
  end

  def test_copy_helper_delegates_and_sets_document_lang
    helper = Object.new.extend(RecordingStudioTrashable::CopyHelper)

    assert_equal "Trash", helper.trashable_t("trash.title")
    assert_equal "Host bin", helper.trashable_copy("Host bin", "trash.title")
    assert_equal "en", helper.trashable_document_attributes[:lang]
    assert_equal "fr", helper.trashable_document_attributes(lang: "fr")[:lang]
  end

  def test_copy_l_formats_dates
    I18n.backend.store_translations(:en, { date: { formats: { long: "%B %d, %Y" } } })

    assert_equal "January 03, 2026", Copy.l(Date.new(2026, 1, 3), format: :long)
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio").fetch("trashable")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end

  def acme_title
    { recording_studio: { trashable: { trash: { title: "Acme bin" } } } }
  end

  def default_title
    { recording_studio: { trashable: { trash: { title: "Trash" } } } }
  end

  def html_note
    # I18n interpolation, not a Ruby format string.
    { recording_studio: { trashable: { note_html: "<b>%{name}</b>" } } } # rubocop:disable Style/FormatStringToken
  end
end
