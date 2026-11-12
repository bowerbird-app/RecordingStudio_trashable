# frozen_string_literal: true

module RecordingStudioTrashable
  module Api
    module Errors
      INPUT_ERRORS = [
        ArgumentError,
        RecordingStudioTrashable::PurgeTargetsNotTrashedError,
        (RecordingStudio::CapabilityDisabled if defined?(RecordingStudio::CapabilityDisabled))
      ].compact.freeze

      module_function

      def wrap
        yield
      rescue RecordingStudioApi::NotFoundError, RecordingStudioApi::AuthorizationError
        raise
      rescue *INPUT_ERRORS => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
