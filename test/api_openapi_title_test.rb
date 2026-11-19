# frozen_string_literal: true

require "test_helper"

class ApiOpenapiTitleTest < Minitest::Test
  ACTIONS = %i[
    trashable_trash
    trashable_restore
    trashable_purge
    trashable_list_trash_bin
  ].freeze
  PAGE_TITLES = {
    trashable_trash: "Trash page",
    trashable_restore: "Restore page",
    trashable_purge: "Purge page",
    trashable_list_trash_bin: "List page trash bin"
  }.freeze
  VIDEO_TITLES = {
    trashable_trash: "Trash video",
    trashable_restore: "Restore video",
    trashable_purge: "Purge video",
    trashable_list_trash_bin: "List video trash bin"
  }.freeze

  def test_declared_types_get_per_type_titles
    with_recordable_types("Page", "Video", "PressCenter", "SupportPage") do
      PAGE_TITLES.each do |action, title|
        document = openapi(type: "Page", action: action)

        assert_equal title, document.fetch(:title), action.to_s
        assert_equal "Trash", document.fetch(:tag_suffix)
        assert_includes document.fetch(:description), "Returns"
      end

      VIDEO_TITLES.each do |action, title|
        assert_equal title, openapi(type: "Video", action: action).fetch(:title), action.to_s
      end

      assert_equal "Trash press center", openapi(type: "PressCenter", action: :trashable_trash).fetch(:title)
      assert_equal "List press center trash bin",
                   openapi(type: "PressCenter", action: :trashable_list_trash_bin).fetch(:title)
      assert_equal "Purge support page", openapi(type: "SupportPage", action: :trashable_purge).fetch(:title)
    end
  end

  def test_override_replaces_one_type_and_leaves_the_capability_title
    with_recordable_types("Page", "Video") do
      RecordingStudioTrashable::Api.override_openapi(
        type: "Page",
        action: :trashable_trash,
        title: "Bin this page",
        description: "Custom page trash copy."
      )

      page = openapi(type: "Page", action: :trashable_trash)
      video = openapi(type: "Video", action: :trashable_trash)
      generic = RecordingStudioTrashable::Api::Catalog.openapi_for(:trashable_trash)

      assert_equal "Bin this page", page.fetch(:title)
      assert_equal "Custom page trash copy.", page.fetch(:description)
      assert_equal "Trash", page.fetch(:tag_suffix)
      assert_equal "Trash video", video.fetch(:title)
      assert_includes video.fetch(:description), "Returns"
      assert_equal "Trash", generic.fetch(:title)
      assert_equal "Move this recording to the trash.", generic.fetch(:summary)
    end
  ensure
    RecordingStudioTrashable::Api::OpenapiOverrides.reset!
  end

  def test_unknown_type_returns_nil_and_an_override_still_wins
    with_recordable_types("Page") do
      assert_nil openapi(type: "NotARecordable", action: :trashable_trash)
      assert_nil openapi(type: "", action: :trashable_restore)

      RecordingStudioTrashable::Api.override_openapi(
        type: "NotARecordable",
        action: :trashable_purge,
        title: "Purge the stray",
        description: "Custom purge copy."
      )

      stray = openapi(type: "NotARecordable", action: :trashable_purge)

      assert_equal "Purge the stray", stray.fetch(:title)
      assert_equal "Custom purge copy.", stray.fetch(:description)
      assert_equal "Trash page", openapi(type: "Page", action: :trashable_trash).fetch(:title)
    end
  ensure
    RecordingStudioTrashable::Api::OpenapiOverrides.reset!
  end

  def test_unknown_action_raises
    error = assert_raises(ArgumentError) do
      RecordingStudioTrashable::Api.openapi_for(type: "Page", action: :trashable_nope)
    end

    assert_match(/Unknown trashable action/, error.message)
  end

  def test_registration_callback_returns_the_per_type_title
    with_recordable_types("Page", "Video") do
      options = RecordingStudioTrashable::Api.action_options(:public, :trashable_trash)

      assert_equal "Trash", options.fetch(:openapi).fetch(:title)
      assert_equal "Trash", options.fetch(:openapi).fetch(:tag_suffix)
      assert_equal(
        "Trash page",
        options.fetch(:openapi_for).call(type: "Page", action: :trashable_trash).fetch(:title)
      )
      assert_equal(
        "Trash video",
        options.fetch(:openapi_for).call(type: "Video", action: :trashable_trash).fetch(:title)
      )
      assert_nil options.fetch(:openapi_for).call(type: "NotARecordable", action: :trashable_trash)
    end
  end

  private

  def openapi(type:, action:)
    RecordingStudioTrashable::Api.openapi_for(type: type, action: action)
  end

  def with_recordable_types(*types)
    configuration = RecordingStudio.configuration
    previous = configuration.recordable_types.dup
    configuration.recordable_types = types
    yield
  ensure
    configuration.recordable_types = previous if configuration && previous
  end
end
