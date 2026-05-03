# frozen_string_literal: true

require "test_helper"

class HooksTest < Minitest::Test
  def setup
    @hooks = RecordingStudioTrashable::Hooks.new
  end

  def test_run_executes_registered_hooks_in_priority_order
    calls = []
    @hooks.after_initialize(priority: 20) { calls << :late }
    @hooks.after_initialize(priority: 10) { calls << :early }

    @hooks.run(:after_initialize)

    assert_equal %i[early late], calls
  end

  def test_clear_bang_removes_registered_hooks
    @hooks.before_initialize { nil }

    @hooks.clear!

    refute @hooks.registered?(:before_initialize)
  end

  def test_raise_on_error_wraps_failures
    @hooks.raise_on_error = true
    @hooks.on(:demo) { raise "boom" }

    assert_raises(RecordingStudioTrashable::Hooks::HookError) do
      @hooks.run(:demo)
    end
  end
end
