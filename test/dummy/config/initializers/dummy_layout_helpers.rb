# frozen_string_literal: true

# The forked recording_studio/default_layout is also used by mounted engine screens.
ActiveSupport.on_load(:action_view) do
  include DummyLayoutHelper
end
