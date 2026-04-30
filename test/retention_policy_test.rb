# frozen_string_literal: true

require "test_helper"

class RetentionPolicyTest < Minitest::Test
  DummySetting = Struct.new(:purge_after_days)
  DummyRecording = Struct.new(:trashed_at)

  def setup
    @original_configuration = RecordingStudioTrashable.instance_variable_get(:@configuration)
    RecordingStudioTrashable.instance_variable_set(:@configuration, RecordingStudioTrashable::Configuration.new)
    return if RecordingStudioTrashable.const_defined?(:RetentionSetting)

    klass = Class.new do
      def self.find_by(*)
        nil
      end
    end
    RecordingStudioTrashable.const_set(:RetentionSetting, klass)
    @defined_retention_setting = true
  end

  def teardown
    RecordingStudioTrashable.send(:remove_const, :RetentionSetting) if @defined_retention_setting
    RecordingStudioTrashable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_normalize_purge_after_days_returns_integer_or_nil
    assert_equal 14, RecordingStudioTrashable::RetentionPolicy.normalize_purge_after_days("14")
    assert_nil RecordingStudioTrashable::RetentionPolicy.normalize_purge_after_days("bad")
    assert_nil RecordingStudioTrashable::RetentionPolicy.normalize_purge_after_days("")
  end

  def test_purge_after_days_uses_scope_setting_before_default
    scope_recording = :scope
    RecordingStudioTrashable.configure { |config| config.default_purge_after_days = 30 }

    RecordingStudioTrashable::RetentionSetting.stub(:find_by, DummySetting.new(7)) do
      assert_equal 7, RecordingStudioTrashable::RetentionPolicy.purge_after_days_for(scope_recording)
    end
  end

  def test_purge_after_days_treats_persisted_blank_scope_setting_as_manual_only
    RecordingStudioTrashable.configure { |config| config.default_purge_after_days = 30 }

    RecordingStudioTrashable::RetentionSetting.stub(:find_by, DummySetting.new(nil)) do
      RecordingStudio.stub(:capability_options, { purge_after_days: 14 }) do
        assert_nil RecordingStudioTrashable::RetentionPolicy.purge_after_days_for(:scope, recordable_type: "Page")
      end
    end
  end

  def test_purge_after_days_uses_recordable_capability_override_before_default
    RecordingStudioTrashable.configure { |config| config.default_purge_after_days = 30 }

    RecordingStudioTrashable::RetentionSetting.stub(:find_by, nil) do
      RecordingStudio.stub(:capability_options, { purge_after_days: 14 }) do
        assert_equal 14, RecordingStudioTrashable::RetentionPolicy.purge_after_days_for(:scope, recordable_type: "Page")
      end
    end
  end

  def test_due_reports_true_once_deadline_passes
    recording = DummyRecording.new(Time.now - 10.days)

    RecordingStudioTrashable::RetentionPolicy.stub(:purge_after_days_for, 7) do
      assert RecordingStudioTrashable::RetentionPolicy.due?(recording: recording, scope_recording: :scope, as_of: Time.now)
    end
  end
end
