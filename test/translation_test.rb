# frozen_string_literal: true

require "test_helper"
require "action_view"
require "action_controller"
require "yaml"
require "fileutils"
require "securerandom"

# Behavioral coverage for RecordingStudio.t fallback on trashable keys.
# Copy.t / trashable_t delegate here; no gem-local Translation helper.
class TranslationTest < Minitest::Test
  GEM_KEYS = {
    "recording_studio.trashable.trash.title" => "Trash",
    "recording_studio.trashable.trash.close" => "Close",
    "recording_studio.trashable.trash.settings" => "Settings",
    "recording_studio.trashable.flashes.settings_updated" => "Trash settings updated.",
    "recording_studio.trashable.errors.purge_after_days_invalid" => "must be a positive whole number",
    "recording_studio.trashable.retention.keep_until_purged" => "Keep until manually purged"
  }.freeze

  EN_YML = File.expand_path("../config/locales/en.yml", __dir__)

  def setup
    @previous_locales = I18n.available_locales
    @previous_locale = I18n.locale
    I18n.available_locales = (Array(@previous_locales) + %i[en fr de xx]).uniq
    I18n.locale = :en
    reseed_gem_english!
    ensure_trashable_shipped_english_registered!
  end

  def teardown
    I18n.locale = @previous_locale if @previous_locale
    I18n.available_locales = @previous_locales if @previous_locales
    reseed_gem_english!
    restore_trashable_shipped_english_registration!
  end

  def test_english_locale_resolves_every_probe_gem_key
    I18n.with_locale(:en) do
      GEM_KEYS.each do |key, english|
        assert_equal english, RecordingStudio.t(key)
        assert_equal english, RecordingStudioTrashable::Copy.t(key.delete_prefix("recording_studio.trashable."))
      end
    end
  end

  def test_shipped_english_table_includes_trashable_en_yml_keys
    RecordingStudio::Translation.reset_shipped_english!
    en_yml = YAML.safe_load_file(EN_YML, aliases: true)
                 .fetch("en").fetch("recording_studio").fetch("trashable")
    expected = flatten_locale_keys(en_yml, %w[recording_studio trashable])

    table = RecordingStudio::Translation.shipped_english
    expected.each do |key, value|
      assert_equal value, table.fetch(key), "#{key} must come from registered trashable en.yml"
    end
    assert_predicate table, :frozen?
    assert_same table, RecordingStudio::Translation.shipped_english
  end

  def test_deleted_loaded_english_falls_back_to_registered_shipped_table
    GEM_KEYS.each_key do |key|
      delete_loaded_translation!(:en, key)
      delete_loaded_translation!(:fr, key)
    end

    GEM_KEYS.each do |key, english|
      refute I18n.exists?(key, :en), "#{key} must be absent from loaded :en"
      I18n.with_locale(:en) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
      I18n.with_locale(:fr) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
    end
  ensure
    reseed_gem_english!
  end

  def test_missing_locale_falls_back_to_loaded_english
    I18n.with_locale(:de) do
      GEM_KEYS.each do |key, english|
        refute locale_has_own_translation?(:de, key),
               "#{key} must be absent in :de for this test"
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
    end
  end

  def test_parity_matrix_non_gem_keys_match_i18n_t
    force_i18n_init!
    I18n.backend.store_translations(:en, {
                                      probe: {
                                        greet: "Hi %<name>s",
                                        empty: "",
                                        nil_value: nil,
                                        nest: { a: "A" },
                                        html_key_html: "<b>x</b>",
                                        items: { one: "one item", other: "%<count>s items" }
                                      }
                                    })
    I18n.backend.store_translations(:de, { probe: { greet: "Hallo %<name>s" } })

    I18n.with_locale(:de) do
      assert_parity("probe.greet", name: "M")
      assert_parity("probe.missing")
      assert_parity("probe.missing", default: "D")
      assert_parity("probe.empty")
      assert_parity("probe.nil_value")
      assert_parity("probe.nest")
      assert_parity("probe.items", count: 1)
      assert_parity("probe.items", count: 5)
      assert_parity(:"probe.greet", name: "M")
      assert_parity(%w[probe.missing probe.greet], name: "M")
      assert_parity("greet", scope: "probe", name: "M")
      assert_raise_parity("probe.missing", raise: true)
      assert_parity("probe.greet", locale: :en, name: "M")
      assert_parity("probe.html_key_html")
    end
  end

  def test_parity_matrix_gem_keys_cover_missing_default_raise_nil_empty_hash_and_related_options
    key = "recording_studio.trashable.trash.title"
    missing = "recording_studio.trashable.trash.missing_key_for_parity"

    force_i18n_init!
    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        trashable: {
                                          trash: {
                                            nil_value: nil,
                                            empty_value: "",
                                            nest: { a: "A" },
                                            html_key_html: "<i>g</i>",
                                            items: { one: "one", other: "%<count>s many" },
                                            greet: "Hi %<name>s"
                                          }
                                        }
                                      }
                                    })

    I18n.with_locale(:en) do
      assert_equal I18n.t(key), RecordingStudio.t(key)
      assert_equal "Trash", RecordingStudio.t(key, default: "Ignored when present")
    end

    I18n.with_locale(:de) do
      assert_equal "Trash", RecordingStudio.t(key)
      assert_match(/translation missing/i, I18n.t(key))

      assert_parity(missing)
      assert_parity(missing, default: "D")
      assert_raise_parity(missing, raise: true)

      I18n.backend.store_translations(:de, {
                                        recording_studio: { trashable: { trash: { title: "DE Corbeille" } } }
                                      })
      assert_equal "DE Corbeille", RecordingStudio.t(key)
      assert_equal I18n.t(key), RecordingStudio.t(key)

      assert_parity("recording_studio.trashable.trash.nil_value")
      assert_equal "", RecordingStudio.t("recording_studio.trashable.trash.empty_value")
      assert_match(/translation missing/i, I18n.t("recording_studio.trashable.trash.empty_value"))

      assert_equal(
        I18n.t("recording_studio.trashable.trash.nest", locale: :en),
        RecordingStudio.t("recording_studio.trashable.trash.nest")
      )
      assert_equal(
        I18n.t("recording_studio.trashable.trash.items", locale: :en, count: 1),
        RecordingStudio.t("recording_studio.trashable.trash.items", count: 1)
      )
      assert_equal(
        I18n.t("recording_studio.trashable.trash.greet", locale: :en, name: "M"),
        RecordingStudio.t("recording_studio.trashable.trash.greet", name: "M")
      )

      assert_equal "DE Corbeille", RecordingStudio.t(:"recording_studio.trashable.trash.title")
      assert_equal(
        ["DE Corbeille", "Close"],
        RecordingStudio.t(%w[
                            recording_studio.trashable.trash.title
                            recording_studio.trashable.trash.close
                          ])
      )
      assert_equal "DE Corbeille", RecordingStudio.t(:title, scope: "recording_studio.trashable.trash")
      assert_equal "Close", RecordingStudio.t(:close, scope: "recording_studio.trashable.trash")

      html = RecordingStudio.t("recording_studio.trashable.trash.html_key_html")
      assert_equal "<i>g</i>", html
      assert_predicate html, :html_safe?

      assert_equal "D", RecordingStudio.t(missing, default: "D")

      I18n.backend.store_translations(:en, {
                                        recording_studio: {
                                          trashable: { trash: { missing_key_for_parity: "EN" } }
                                        }
                                      })
      assert_equal "EN", RecordingStudio.t(missing, default: "D")

      error = assert_raises(I18n::MissingTranslationData) do
        RecordingStudio.t("recording_studio.trashable.trash.totally_absent", raise: true)
      end
      assert_match(/Translation missing: de\.recording_studio/, error.message)

      assert_equal "Trash", RecordingStudio.t(key, locale: :en)
    end
  end

  def test_fallback_order_prefers_loaded_english_then_caller_default_over_shipped_table
    key = "recording_studio.trashable.trash.title"

    force_i18n_init!
    write_loaded_translation!(:en, key, "HOST EN Trash")
    assert_equal "HOST EN Trash", I18n.t(key, locale: :en)
    I18n.with_locale(:de) do
      refute locale_has_own_translation?(:de, key)
      assert_equal "HOST EN Trash", RecordingStudio.t(key),
                   "host :en override must win over the gem-shipped table"
    end

    delete_loaded_translation!(:en, key)
    delete_loaded_translation!(:fr, key)
    %i[en fr de].each do |locale|
      I18n.with_locale(locale) do
        assert_equal "CALLER", RecordingStudio.t(key, default: "CALLER"),
                     "caller default: must come before the gem-shipped table in #{locale}"
      end

      I18n.with_locale(locale) do
        assert_equal "Trash", RecordingStudio.t(key),
                     "shipped table is last and matches en.yml in #{locale}"
      end
    end
  ensure
    reseed_gem_english!
  end

  def test_html_gem_keys_escape_unsafe_interpolation_like_view_t
    force_i18n_init!
    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        trashable: {
                                          probe: {
                                            hi_html: "<b>Hi %<name>s</b>",
                                            greet: "Hi %<name>s",
                                            items_html: {
                                              one: "<i>1 x</i>",
                                              other: "<i>%<count>s xs</i>"
                                            }
                                          }
                                        }
                                      }
                                    })
    view = ActionController::Base.helpers

    I18n.with_locale(:en) do
      value = RecordingStudio.t("recording_studio.trashable.probe.hi_html", name: "<script>")
      assert_equal "<b>Hi &lt;script&gt;</b>", value
      assert_predicate value, :html_safe?
      assert_equal view.t("recording_studio.trashable.probe.hi_html", name: "<script>"), value

      plain = RecordingStudio.t("recording_studio.trashable.probe.greet", name: "<s>")
      assert_equal "Hi <s>", plain
      refute_predicate plain, :html_safe?

      safe_arg = "<u>ok</u>".html_safe
      with_safe = RecordingStudio.t("recording_studio.trashable.probe.hi_html", name: safe_arg)
      assert_equal "<b>Hi <u>ok</u></b>", with_safe

      plural = RecordingStudio.t("recording_studio.trashable.probe.items_html", count: 2)
      assert_equal "<i>2 xs</i>", plural
      assert_predicate plural, :html_safe?

      singular = RecordingStudio.t("recording_studio.trashable.probe.items_html", count: 1)
      assert_equal "<i>1 x</i>", singular
      assert_predicate singular, :html_safe?

      missing_html = "recording_studio.trashable.probe.missing_key_html"
      reserved = RecordingStudio.t(missing_html, default: "<b>ok</b>")
      assert_equal "<b>ok</b>", reserved
      refute_predicate reserved, :html_safe?

      xss = RecordingStudio.t("recording_studio.trashable.probe.hi_html", name: "<script>alert(1)</script>")
      refute_includes xss, "<script>"
      assert_includes xss, "&lt;script&gt;"
    end
  end

  # Unit suite registers en.yml in setup so fallback tests can run without a
  # Rails app. Boot registration (initializer alone) is asserted in
  # test/dummy/test/integration/english_fallback_test.rb — do not call
  # register_shipped_english or the initializer block there.
  def test_shipped_english_table_includes_trashable_keys_after_unit_registration
    table = RecordingStudio::Translation.shipped_english
    refute_empty table
    assert_equal "Trash", table.fetch("recording_studio.trashable.trash.title")
  end

  def test_production_recording_studio_t_is_only_used_for_trashable_copy
    roots = [
      File.expand_path("../app", __dir__),
      File.expand_path("../lib", __dir__)
    ]
    offenders = []

    roots.each do |root|
      Dir[File.join(root, "**/*.{rb,erb}")].each do |path|
        next if path.include?("/generators/")

        source = File.read(path)
        next unless source.include?("RecordingStudio.t(")

        relative = path.delete_prefix("#{File.expand_path('..', __dir__)}/")
        next if relative == "lib/recording_studio_trashable/copy.rb"

        offenders << relative
      end
    end

    assert_empty offenders, <<~MSG
      RecordingStudio.t is only for recording_studio.trashable.* (via Copy.t).
      Host or other-namespace keys must stay on I18n.t with main's defaults.
      #{offenders.join("\n")}
    MSG

    copy_source = File.read(File.expand_path("../lib/recording_studio_trashable/copy.rb", __dir__))
    assert_includes copy_source, 'PREFIX = "recording_studio.trashable"'
    assert_match(/RecordingStudio\.t\("#\{PREFIX\}\.#\{key\}", \*\*\)/, copy_source)
  end

  def test_host_flatpack_nav_labels_stay_on_i18n_t
    helper = File.read(File.expand_path("dummy/app/helpers/dummy_layout_helper.rb", __dir__))

    assert_includes helper, 'I18n.t("flatpack.page_nav.back")'
    assert_includes helper, 'I18n.t("flatpack.page_nav.close")'
    refute_includes helper, "RecordingStudio.t("
  end

  def test_missing_registered_trashable_en_yml_contributes_empty_table_slice
    missing_path = File.expand_path("../tmp/missing_trashable_en_#{Process.pid}.yml", __dir__)
    refute File.exist?(missing_path)

    with_shipped_english_registrations([missing_path]) do
      table = RecordingStudio::Translation.shipped_english
      assert_predicate table, :frozen?
      refute table.key?("recording_studio.trashable.trash.title"),
             "missing registered path must not contribute trashable keys"
      assert_equal I18n.t("recording_studio.trashable.absent_for_missing_yml"),
                   RecordingStudio.t("recording_studio.trashable.absent_for_missing_yml")
    end
  end

  def test_global_i18n_config_snapshot_is_unchanged_by_recording_studio_t
    before = i18n_config_snapshot

    RecordingStudio.t("recording_studio.trashable.trash.title")
    I18n.with_locale(:de) do
      RecordingStudio.t("recording_studio.trashable.trash.title")
      RecordingStudio.t("not_a_gem_key")
    end

    assert_equal before, i18n_config_snapshot
  end

  def test_lazy_keys_pass_through_like_i18n_t
    I18n.with_locale(:en) do
      assert_equal I18n.t(".lazy_key_without_scope"), RecordingStudio.t(".lazy_key_without_scope")
    end
  end

  def test_copy_t_routes_through_recording_studio_t
    source = File.read(File.expand_path("../lib/recording_studio_trashable/copy.rb", __dir__))
    assert_includes source, "RecordingStudio.t("
    refute_includes source, "I18n.t(full_key"
  end

  private

  def ensure_trashable_shipped_english_registered!
    @previous_registered_paths =
      RecordingStudio::Translation.send(:registered_shipped_english_paths).dup
    RecordingStudio::Translation.register_shipped_english(EN_YML)
    RecordingStudio::Translation.reset_shipped_english!
    RecordingStudio::Translation.shipped_english
  end

  def restore_trashable_shipped_english_registration!
    return unless @previous_registered_paths

    RecordingStudio::Translation.instance_variable_set(
      :@registered_shipped_english_paths,
      @previous_registered_paths
    )
    RecordingStudio::Translation.reset_shipped_english!
    RecordingStudio::Translation.shipped_english
  end

  def with_shipped_english_registrations(paths)
    translation = RecordingStudio::Translation
    previous = translation.instance_variable_get(:@registered_shipped_english_paths)
    translation.instance_variable_set(:@registered_shipped_english_paths, paths.dup)
    translation.reset_shipped_english!
    yield
  ensure
    translation.instance_variable_set(:@registered_shipped_english_paths, previous)
    translation.reset_shipped_english!
    translation.shipped_english
  end

  def force_i18n_init!
    I18n.t("recording_studio.trashable.trash.title")
  end

  def reseed_gem_english!
    clear_locale_tree!(:de, %w[recording_studio trashable])
    clear_locale_tree!(:fr, %w[recording_studio trashable])
    clear_locale_tree!(:xx, %w[recording_studio trashable])
    tree = YAML.safe_load_file(EN_YML, aliases: true).fetch("en")
    I18n.backend.store_translations(:en, tree)
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- backend hash walk
  def clear_locale_tree!(locale, parts)
    I18n.backend.send(:init_translations) unless I18n.backend.initialized?
    translations = I18n.backend.send(:translations)
    locale_key = locale.to_sym
    return unless translations[locale_key].is_a?(Hash)

    translations[locale_key] = translations[locale_key].dup if translations[locale_key].frozen?
    node = translations[locale_key]
    parts[0...-1].each do |part|
      key = part.to_sym
      break unless node.is_a?(Hash) && node[key].is_a?(Hash)

      node[key] = node[key].dup if node[key].frozen?
      node = node[key]
    end
    node.delete(parts.last.to_sym) if node.is_a?(Hash)
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def locale_has_own_translation?(locale, full_key)
    I18n.backend.send(:init_translations) unless I18n.backend.initialized?
    node = I18n.backend.send(:translations)[locale.to_sym]
    return false unless node.is_a?(Hash)

    full_key.split(".").map(&:to_sym).each do |part|
      return false unless node.is_a?(Hash) && node.key?(part)

      node = node[part]
    end
    !node.nil?
  end

  def assert_parity(key, **options)
    expected = I18n.t(key, **options)
    actual = RecordingStudio.t(key, **options)
    assert_equal expected, actual, "parity failed for #{key.inspect} options=#{options.inspect}"
    return unless actual.is_a?(String) && key.to_s.match?(/(\b|_|\.)html\z/)

    assert_equal expected.html_safe?, actual.html_safe?
  end

  def assert_raise_parity(key, **options)
    i18n_error = assert_raises(I18n::MissingTranslationData) { I18n.t(key, **options) }
    rs_error = assert_raises(I18n::MissingTranslationData) { RecordingStudio.t(key, **options) }
    assert_equal i18n_error.message, rs_error.message
  end

  def i18n_config_snapshot
    {
      load_path: I18n.load_path.map { |path| File.expand_path(path) },
      available_locales: Array(I18n.available_locales).map(&:to_sym).sort,
      exception_handler: I18n.exception_handler,
      enforce_available_locales: I18n.enforce_available_locales,
      fallbacks_class: (I18n.fallbacks.class.name if I18n.respond_to?(:fallbacks))
    }
  end

  def flatten_locale_keys(node, prefix)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), result|
        result.merge!(flatten_locale_keys(value, prefix + [key.to_s]))
      end
    else
      { prefix.join(".") => node }
    end
  end

  def delete_loaded_translation!(locale, full_key)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node.delete(leaf) }
  end

  def write_loaded_translation!(locale, full_key, value)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node[leaf] = value }
  end

  # rubocop:disable Metrics/CyclomaticComplexity -- backend hash walk
  def mutate_loaded_translation!(locale, full_key)
    I18n.exists?(full_key, locale)
    parts = full_key.split(".").map(&:to_sym)
    leaf = parts.pop
    translations = I18n.backend.send(:translations)
    locale_key = locale.to_sym
    translations[locale_key] = translations[locale_key].dup if translations[locale_key].frozen?

    node = translations[locale_key]
    parts.each do |part|
      break unless node.is_a?(Hash) && node[part].is_a?(Hash)

      node[part] = node[part].dup if node[part].frozen?
      node = node[part]
    end
    yield node, leaf if node.is_a?(Hash)
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
