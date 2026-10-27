# frozen_string_literal: true

require_relative "../test_helper"

class CustomerI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    Current.actor = @user
    @workspace = Workspace.find_by(name: "I18n Workspace") || Workspace.create!(name: "I18n Workspace")
    @workspace_recording = RecordingStudio.root_recording_for(@workspace)
  end

  test "home top nav has sign out and no language selector" do
    sign_in @user
    get "/"

    assert_response :success
    assert_select "html[lang='en']"
    header = response.body[/<header[\s\S]*?<\/header>/].to_s
    assert_includes header, "Sign out"
    refute_includes response.body, "dummy-language-selector"
    refute_includes response.body, "recording_studio_internationalization/locale"
  end

  test "trash screen stays English by default" do
    sign_in @user
    recording = trash_demo_recording("English Demo Page")
    recording.recording_studio_trashable_trash!(actor: @user)

    get "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_bin"

    assert_response :success
    assert_select "html[lang='en']"
    assert_includes response.body, "Trash"
    assert_includes response.body, "Search trash"
    assert_includes response.body, "Settings"
    assert_includes response.body, "Name"
    assert_includes response.body, "Type"
    assert_includes response.body, "Trashed"
    assert_includes response.body, "Action"
    assert_includes response.body, "Restore"
    assert_includes response.body, "Purge"
    assert_includes response.body, "English Demo Page"
    assert_includes response.body, "Restore English Demo Page?"
    assert_includes response.body, "Permanently delete English Demo Page?"
    assert_includes response.body, "Page"
  end

  test "empty trash screen stays English by default" do
    sign_in @user
    empty_workspace = Workspace.create!(name: "Empty I18n Workspace")
    empty_recording = RecordingStudio.root_recording_for(empty_workspace)

    get "/recording_studio_trashable/recordings/#{empty_recording.id}/trash_bin"

    assert_response :success
    assert_includes response.body, "Nothing in the trash."
    refute_includes response.body, "Rien dans la corbeille."
  end

  test "engine overview page stays English by default" do
    sign_in @user
    get "/recording_studio_trashable"

    assert_response :success
    assert_includes response.body, "Overview"
    assert_includes response.body, "Capabilities"
    assert_includes response.body, "What this addon owns"
    assert_includes response.body, "Mounted screens and trash actions that stay out of Recording Studio core."
    assert_includes response.body, "for soft delete."
    assert_includes response.body, "for bringing an item back."
    assert_includes response.body, "for permanent delete."
    assert_includes response.body, "Explicit query helpers instead of another default scope."
    assert_includes response.body, "Keep-for settings stored on each workspace or folder you pick."
    assert_includes response.body, "Authorization"
    assert_includes response.body, "Default authorization"
    assert_includes response.body, "Built-in Accessible checks can be kept, turned off, or replaced."
    assert_includes response.body, "recording_studio_trashable_trash!"
    assert_includes response.body, "<dt class=\"font-medium\">trash</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">restore</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">purge</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">settings</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">trash_bin</dt>"
    refute_includes response.body, "Aperçu"
    refute_includes response.body, "Capacités"
  end

  test "retention settings page stays English by default" do
    sign_in @user
    get "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_settings/edit"

    assert_response :success
    assert_includes response.body, "Retention period"
    assert_includes response.body, "Number of days to keep trashed items."
    assert_includes response.body, "Keep until manually purged"
    assert_includes response.body, "Save"
    refute_includes response.body, "Durée de conservation"
  end

  test "dummy French locale renders trash copy while stored names stay English" do
    sign_in @user
    recording = trash_demo_recording("French Demo Page")
    recording.recording_studio_trashable_trash!(actor: @user)

    switch_to_french
    get "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_bin"

    assert_response :success
    assert_select "html[lang='fr']"
    assert_includes response.body, "Corbeille"
    assert_includes response.body, "Rechercher dans la corbeille"
    assert_includes response.body, "Restaurer"
    assert_includes response.body, "Supprimer"
    assert_includes response.body, "French Demo Page"
    assert_includes response.body, "Restaurer French Demo Page ?"
    assert_includes response.body, "Supprimer définitivement French Demo Page ?"
    assert_includes response.body, "Page"
    refute_includes response.body, "Search trash"
    refute_includes response.body, "Nothing in the trash."
  end

  test "dummy French locale renders empty trash copy" do
    sign_in @user
    empty_workspace = Workspace.create!(name: "Empty French Workspace")
    empty_recording = RecordingStudio.root_recording_for(empty_workspace)

    switch_to_french
    get "/recording_studio_trashable/recordings/#{empty_recording.id}/trash_bin"

    assert_response :success
    assert_includes response.body, "Rien dans la corbeille."
    refute_includes response.body, "Nothing in the trash."
  end

  test "copy overrides still win over French locale" do
    # Load YAML first. store_translations before init is wiped on first lookup.
    I18n.t("recording_studio.trashable.trash.title", locale: :fr)
    I18n.backend.store_translations(:fr, override_title)
    sign_in @user
    switch_to_french
    empty_workspace = Workspace.create!(name: "Override Workspace")
    empty_recording = RecordingStudio.root_recording_for(empty_workspace)

    get "/recording_studio_trashable/recordings/#{empty_recording.id}/trash_bin"

    assert_response :success
    assert_includes response.body, "Poubelle Acme"
    refute_includes response.body, ">Corbeille<"
  ensure
    I18n.backend.store_translations(:fr, default_french_title)
  end

  private

  def switch_to_french
    patch "/recording_studio_internationalization/locale", params: { locale: "fr", return_to: "/" }
    follow_redirect!
  end

  def trash_demo_recording(title)
    @workspace_recording.record(Page, actor: @user, parent_recording: @workspace_recording) do |page|
      page.title = title
      page.slug = "#{title.parameterize}-#{SecureRandom.hex(4)}"
      page.body = "I18n demo page"
    end
  end

  def override_title
    { recording_studio: { trashable: { trash: { title: "Poubelle Acme" } } } }
  end

  def default_french_title
    { recording_studio: { trashable: { trash: { title: "Corbeille" } } } }
  end
end
