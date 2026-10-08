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

  test "language selector sits in the dummy top nav left of sign out" do
    sign_in @user
    get "/"

    assert_response :success
    assert_select "form[action='/recording_studio_internationalization/locale']"
    assert_includes response.body, "English"
    assert_includes response.body, "Français"
    assert_select "html[lang='en']"
    header = response.body[/<nav[\s\S]*?<\/nav>/].to_s
    header = response.body if header.blank?
    language_at = header.index("dummy-language-selector")
    sign_out_at = header.index("Sign out")
    assert language_at, "expected a language selector in the top nav"
    assert sign_out_at, "expected Sign out in the top nav"
    assert language_at < sign_out_at, "language selector should sit left of Sign out"
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
