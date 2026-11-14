# frozen_string_literal: true

require_relative "../test_helper"

class RecordingFilterTest < ActiveSupport::TestCase
  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    Current.actor = @user
    @root = workspace_root
    @parent = record_page(@root, "Parent")
    @child = record_page(@parent, "Child")
    @grandchild = record_page(@child, "Grandchild")
  end

  test "kept hides trashed rows and kept_sql filters a join alias" do
    earlier = Time.utc(2026, 10, 1, 0, 0, 0)
    time = Time.utc(2026, 10, 13, 12, 0, 0)
    @child.update_columns(trashed_at: earlier, updated_at: earlier)

    RecordingStudioTrashable.void_recording!(@parent, time: time)

    @parent.reload
    @child.reload
    @grandchild.reload

    assert_in_delta time.to_f, @parent.trashed_at.to_f, 1
    assert_in_delta earlier.to_f, @child.trashed_at.to_f, 1
    assert_in_delta time.to_f, @grandchild.trashed_at.to_f, 1
    assert_equal false, @parent.trash_root
    assert_equal false, @child.trash_root
    assert_equal false, @grandchild.trash_root
    assert_nil @root.reload.trashed_at
    assert_equal 0, @parent.events.where(action: "trashed").count

    kept_ids = RecordingStudio::Recording.kept.where(id: [ @root.id, @parent.id, @child.id, @grandchild.id ]).pluck(:id)
    assert_includes kept_ids, @root.id
    refute_includes kept_ids, @parent.id
    refute_includes kept_ids, @child.id
    refute_includes kept_ids, @grandchild.id
    assert_includes RecordingStudio::Recording.where(id: @parent.id), @parent

    quoted_parents = quote_identifier("parents")
    assert_equal "(#{quoted_parents}.trashed_at IS NULL)", RecordingStudio.kept_sql("parents")
    assert_equal "(#{quoted_parents}.trashed_at IS NULL)", RecordingStudio.kept_sql(:parents)

    ids = RecordingStudio::Recording.connection.select_values(<<~SQL.squish)
      SELECT children.id::text
      FROM recording_studio_recordings children
      INNER JOIN recording_studio_recordings parents
        ON parents.id = children.parent_recording_id
      WHERE #{RecordingStudio.kept_sql("parents")}
        AND children.root_recording_id = #{RecordingStudio::Recording.connection.quote(@root.id)}
    SQL

    assert_includes ids, @parent.id
    refute_includes ids, @child.id
    refute_includes ids, @grandchild.id
    refute_includes ids, @root.id
  end

  test "the trashable filter still hides trashed rows after a reload" do
    @parent.update_columns(trashed_at: Time.current, updated_at: Time.current)
    parent_id = @parent.id
    cache_classes = Rails.application.config.cache_classes
    Rails.application.config.cache_classes = false

    Rails.application.reloader.reload!

    refute RecordingStudio::Recording.kept.exists?(id: parent_id)
    assert_equal 1, RecordingStudio.kept_sql.scan("trashed_at").size
    assert_empty RecordingStudio::Recording.default_scopes
  ensure
    Rails.application.config.cache_classes = cache_classes
  end

  test "an unmigrated host applies no filter and does not raise" do
    @parent.update_columns(trashed_at: Time.current, updated_at: Time.current)
    with_trashed_at_column(false) do
      assert RecordingStudio::Recording.kept.exists?(id: @parent.id)
      assert_equal "(1=1)", RecordingStudio.kept_sql
      assert_equal "(1=1)", RecordingStudio.kept_sql("parents")
      ids = RecordingStudio::Recording.connection.select_values(<<~SQL.squish)
        SELECT children.id::text
        FROM recording_studio_recordings children
        INNER JOIN recording_studio_recordings parents
          ON parents.id = children.parent_recording_id
        WHERE #{RecordingStudio.kept_sql("parents")}
          AND children.id = #{RecordingStudio::Recording.connection.quote(@parent.id)}
      SQL
      assert_includes ids, @parent.id
    end

    with_trashed_at_column(proc { raise ActiveRecord::NoDatabaseError }) do
      assert_nothing_raised { RecordingStudio.kept_sql("parents") }
      refute_includes RecordingStudio.kept_sql, "trashed_at"
      assert_nothing_raised { RecordingStudio::Recording.kept.where(id: @parent.id).to_sql }
      assert RecordingStudio::Recording.kept.exists?(id: @parent.id)
    end

    called = false
    with_trashed_at_column(proc { called = true
                                  false }) do
      RecordingStudioTrashable::RecordingFilter.register!
    end
    refute called
  end

  private

  def workspace_root
    workspace = Workspace.create!(name: "Filter workspace #{SecureRandom.hex(4)}")
    RecordingStudio.root_recording_for(workspace)
  end

  def record_page(parent, title)
    parent.record(Page, actor: @user, parent_recording: parent) do |page|
      page.title = title
      page.slug = "#{title.parameterize}-#{SecureRandom.hex(4)}"
    end
  end

  def with_trashed_at_column(answer)
    connection = RecordingStudio::Recording.connection
    singleton = connection.singleton_class
    singleton.alias_method(:column_exists_without_test, :column_exists?)
    singleton.define_method(:column_exists?) do |*args, **kwargs, &block|
      answer.respond_to?(:call) ? answer.call(*args, **kwargs, &block) : answer
    end
    yield
  ensure
    if singleton&.method_defined?(:column_exists_without_test) || singleton&.private_method_defined?(:column_exists_without_test)
      singleton.alias_method(:column_exists?, :column_exists_without_test)
      singleton.remove_method(:column_exists_without_test)
    end
  end

  def quote_identifier(identifier)
    RecordingStudio::Recording.connection.quote_table_name(identifier)
  end
end
