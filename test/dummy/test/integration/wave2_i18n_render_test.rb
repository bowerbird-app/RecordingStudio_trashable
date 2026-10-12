# frozen_string_literal: true

require_relative "../test_helper"

# Render-level literal-English asserts for wave 2 leftovers (alongside
# ui_surface_test / customer_i18n_test template greps). English output must
# match main. Does not rewrite those existing tests to expect HOST strings.
class Wave2I18nRenderTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    Current.actor = @user
    @workspace = Workspace.find_by(name: "Wave2 I18n Workspace") ||
                 Workspace.create!(name: "Wave2 I18n Workspace")
    @workspace_recording = RecordingStudio.root_recording_for(@workspace)
  end

  test "overview authorization dt labels render english action names via Copy.action_name" do
    sign_in @user
    get "/recording_studio_trashable"

    assert_response :success
    assert_includes response.body, "<dt class=\"font-medium\">trash</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">restore</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">purge</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">settings</dt>"
    assert_includes response.body, "<dt class=\"font-medium\">trash_bin</dt>"
    assert_includes response.body, "<dd>edit</dd>"
    assert_includes response.body, "<dd>admin</dd>"
  end

  test "trash empty and retention pages render literal english" do
    sign_in @user
    empty_workspace = Workspace.create!(name: "Wave2 Empty #{SecureRandom.hex(4)}")
    empty_recording = RecordingStudio.root_recording_for(empty_workspace)

    get "/recording_studio_trashable/recordings/#{empty_recording.id}/trash_bin"

    assert_response :success
    assert_includes response.body, "Nothing in the trash."
    assert_includes response.body, "Trash"
    assert_includes response.body, "Search trash"

    get "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_settings/edit"

    assert_response :success
    assert_includes response.body, "Retention period"
    assert_includes response.body, "Number of days to keep trashed items."
    assert_includes response.body, "Keep until manually purged"
    assert_includes response.body, "Save"
  end

  test "restore flash renders literal english at the redirect" do
    sign_in @user
    recording = trash_demo_recording("Wave2 Restore Page")
    recording.recording_studio_trashable_trash!(actor: @user)

    patch "/recording_studio_trashable/recordings/#{recording.id}/restore",
          params: { back_path: "/" }

    assert_response :redirect
    assert_equal "Wave2 Restore Page restored", flash[:notice]
  end

  test "settings updated flash renders literal english" do
    sign_in @user

    patch "/recording_studio_trashable/recordings/#{@workspace_recording.id}/trash_settings",
          params: {
            recording_studio_trashable_retention_setting: { purge_after_days: 14 },
            back_path: "/"
          }

    assert_response :redirect
    assert_equal "Trash settings updated.", flash[:notice]
  end

  private

  def trash_demo_recording(title)
    @workspace_recording.record(Page, actor: @user, parent_recording: @workspace_recording) do |page|
      page.title = title
      page.slug = "#{title.parameterize}-#{SecureRandom.hex(4)}"
      page.body = "Wave2 i18n demo page"
    end
  end
end
