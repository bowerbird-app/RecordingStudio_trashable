# frozen_string_literal: true

require_relative "../test_helper"

class TrashableHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  HOST_RETENTION_MANAGED = "HOST Retention settings are managed by the application."
  HOST_EMPTY = "HOST Nothing in the trash."
  OVERRIDE_KEY = "recording_studio.trashable.flashes.retention_managed"
  EMPTY_KEY = "recording_studio.trashable.trash.empty"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_trashable_host.en.yml")
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/trashable_host_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @backend_before = I18n.backend
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    Current.actor = @user
  end

  teardown do
    I18n.backend = @backend_before if @backend_before
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation. Render assertion uses the retention-managed flash.
  test "host locale override for recording_studio.trashable wins on boot order" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_RETENTION_MANAGED
    assert_equal HOST_RETENTION_MANAGED, I18n.t(OVERRIDE_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    workspace = Workspace.create!(name: "Boot Override #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)

    previous_allow = RecordingStudioTrashable.configuration.allow_user_retention_settings
    RecordingStudioTrashable.configuration.allow_user_retention_settings = false

    get "/recording_studio_trashable/recordings/#{root.id}/trash_settings/edit"

    assert_response :redirect
    assert_equal HOST_RETENTION_MANAGED, flash[:alert]
  ensure
    RecordingStudioTrashable.configuration.allow_user_retention_settings = previous_allow
  end

  # Test-only fixture applied via backend.load_translations(file) on top of the
  # already-initialized backend — never mutates I18n.load_path (Marshal).
  test "fresh-backend last-file-wins host fixture overrides gem english on empty trash" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_EMPTY

    sign_in @user

    snapshot = i18n_backend_translations_snapshot
    I18n.t(EMPTY_KEY)
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_EMPTY, I18n.t(EMPTY_KEY)
    assert_equal HOST_RETENTION_MANAGED, I18n.t(OVERRIDE_KEY)

    workspace = Workspace.create!(name: "Host Override Empty #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)

    get "/recording_studio_trashable/recordings/#{root.id}/trash_bin"
    assert_response :success
    assert_includes response.body, HOST_EMPTY
    refute_includes response.body, "HOST Trash"
  ensure
    restore_i18n_backend_translations(snapshot) if snapshot
  end

  private

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, child), result| result[key] = deep_plain_copy(child) }
    when Array
      value.map { |child| deep_plain_copy(child) }
    else
      value
    end
  end
end
