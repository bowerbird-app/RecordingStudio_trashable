# frozen_string_literal: true

require_relative "../test_helper"

# Behavioral renders: a locale without translations shows loaded / shipped
# English for Trashable screens. Uses :de so boot-loaded host English
# overrides and dummy :fr do not interfere with the missing-locale case.
class EnglishFallbackTest < ActionDispatch::IntegrationTest
  TRASH_TITLE_KEY = "recording_studio.trashable.trash.title"
  SETTINGS_KEY = "recording_studio.trashable.flashes.settings_updated"

  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    Current.actor = @user
    @workspace = Workspace.find_by(name: "English Fallback Workspace") ||
                 Workspace.create!(name: "English Fallback Workspace")
    @workspace_recording = RecordingStudio.root_recording_for(@workspace)
    @previous_locales = I18n.available_locales
    I18n.available_locales = (Array(@previous_locales) + %i[en de fr]).uniq
  end

  teardown do
    I18n.locale = I18n.default_locale
    I18n.available_locales = @previous_locales if @previous_locales
  end

  test "missing locale without translations renders gem english on trash bin" do
    I18n.with_locale(:de) do
      refute locale_has_own_translation?(:de, TRASH_TITLE_KEY),
             ":de must not ship its own trash.title"

      sign_in @user
      get "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_bin"

      assert_response :success
      assert_select "h1", text: "Trash"
      assert_includes @response.body, "Search trash"
      refute_match(/translation missing/i, @response.body)
      refute_includes @response.body, "Translation missing"
    end
  end

  test "english render matches gem english strings from main" do
    I18n.with_locale(:en) do
      sign_in @user
      get "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_bin"

      assert_response :success
      assert_select "h1", text: "Trash"
      assert_includes @response.body, "Nothing in the trash."
      assert_includes @response.body, "Search trash"
      refute_match(/translation missing/i, @response.body)
    end
  end

  test "deleted english key on trash bin shows shipped Trash without translation missing" do
    delete_loaded_translation!(:en, TRASH_TITLE_KEY)
    delete_loaded_translation!(:fr, TRASH_TITLE_KEY)

    refute I18n.exists?(TRASH_TITLE_KEY, :en)
    refute I18n.exists?(TRASH_TITLE_KEY, :fr)

    previous_raise = ActionView::Helpers::TranslationHelper.raise_on_missing_translations

    [false, true].each do |raise_on_missing|
      ActionView::Helpers::TranslationHelper.raise_on_missing_translations = raise_on_missing

      %i[en fr].each do |locale|
        I18n.with_locale(locale) do
          sign_in @user
          get "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_bin"

          assert_response :success
          assert_select "h1", text: "Trash"
          refute_match(/translation missing/i, @response.body)
        end
      end
    end
  ensure
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = previous_raise
    I18n.reload!
  end

  # Must fail on its own if the engine initializer does not register en.yml.
  # Do not call register_shipped_english or run the initializer block here.
  test "trashable en.yml path is registered with RecordingStudio::Translation" do
    expected = File.expand_path(
      RecordingStudioTrashable::Engine.root.join("config/locales/en.yml")
    )
    paths = RecordingStudio::Translation.send(:registered_shipped_english_paths)

    assert_includes paths, expected
    table = RecordingStudio::Translation.shipped_english
    refute_nil RecordingStudio::Translation.instance_variable_get(:@shipped_english)
    assert_equal "Trash", table.fetch(TRASH_TITLE_KEY)
    assert_equal "Trash settings updated.", table.fetch(SETTINGS_KEY)
  end

  test "shipped english table becomes a new object after rails reloader reload" do
    before = RecordingStudio::Translation.shipped_english
    refute_empty before
    assert_equal "Trash", before.fetch(TRASH_TITLE_KEY)

    previous_cache_classes = Rails.application.config.cache_classes
    Rails.application.config.cache_classes = false
    RecordingStudioMetrics.registry.reset! if defined?(RecordingStudioMetrics)

    Rails.application.reloader.reload!

    after = RecordingStudio::Translation.shipped_english
    refute_same before, after
    assert_equal before.fetch(TRASH_TITLE_KEY), after.fetch(TRASH_TITLE_KEY)
    assert_predicate after, :frozen?
  ensure
    Rails.application.config.cache_classes = previous_cache_classes unless previous_cache_classes.nil?
  end

  test "global I18n config keeps fallbacks load_path available_locales and exception handler" do
    snapshot = i18n_config_snapshot
    gem_en = File.expand_path(RecordingStudioTrashable::Engine.root.join("config/locales/en.yml"))
    boot_en = Rails.root.join("config/locales/recording_studio_trashable_host.en.yml").to_s

    assert_includes snapshot.fetch(:load_path), File.expand_path(gem_en)
    assert_includes snapshot.fetch(:load_path), File.expand_path(boot_en)
    assert_operator snapshot.fetch(:load_path).index(File.expand_path(gem_en)),
                    :<,
                    snapshot.fetch(:load_path).index(File.expand_path(boot_en))
    assert snapshot.fetch(:exception_handler), "expected an I18n exception handler"
    assert_includes snapshot.fetch(:available_locales), :en
  end

  private

  def i18n_config_snapshot
    {
      load_path: I18n.load_path.map { |path| File.expand_path(path) },
      available_locales: Array(I18n.available_locales).map(&:to_sym).sort,
      exception_handler: I18n.exception_handler,
      enforce_available_locales: I18n.enforce_available_locales,
      fallbacks_class: (I18n.fallbacks.class.name if I18n.respond_to?(:fallbacks))
    }
  end

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

  def delete_loaded_translation!(locale, full_key)
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
    node.delete(leaf) if node.is_a?(Hash)
  end
end
