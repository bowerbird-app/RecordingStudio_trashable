# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioTrashable
  module RecordingScopes
    FILTER_SCOPES = {
      active: :recording_studio_trashable_active,
      trashed: :recording_studio_trashable_trashed,
      all: :recording_studio_trashable_including_trashed
    }.freeze

    extend ActiveSupport::Concern

    included do
      scope :recording_studio_trashable_active, -> { unscope(where: :trashed_at).where(trashed_at: nil) }
      scope :recording_studio_trashable_trashed, -> { unscope(where: :trashed_at).where.not(trashed_at: nil) }
      scope :recording_studio_trashable_including_trashed, -> { unscope(where: :trashed_at) }
      scope :recording_studio_trashable_trash_roots, -> { recording_studio_trashable_trashed.where(trash_root: true) }
      scope :recording_studio_trashable_filter, lambda { |filter|
        filter_key = filter.to_sym
        scope_name = FILTER_SCOPES.fetch(filter_key) do
          raise ArgumentError,
                "Unknown trash filter #{filter.inspect}. Expected one of: #{FILTER_SCOPES.keys.join(', ')}"
        end

        public_send(scope_name)
      }
      scope :recording_studio_trashable_trash_bin, lambda {
        recording_studio_trashable_trash_roots.reorder(trashed_at: :desc, updated_at: :desc)
      }
    end

    SQL_IDENTIFIER = /\A[A-Za-z_][A-Za-z0-9_]*\z/

    class_methods do
      # SQL fragment for joins, recursive CTEs, and other raw SQL that cannot use
      # `recording_studio_trashable_active`. Pass a table/alias such as "child", or a
      # schema-qualified name with exactly one dot (e.g. "public.recording_studio_recordings").
      # Rejects nil. Quotes each identifier part separately. For partial-index WHERE
      # clauses already on `recording_studio_recordings`, keep the unqualified
      # `trashed_at IS NULL` literal instead of calling this helper.
      def recording_studio_trashable_kept_sql(table = table_name)
        "#{recording_studio_trashable_qualify_trashed_at(table)} IS NULL"
      end

      def recording_studio_trashable_trashed_sql(table = table_name)
        "#{recording_studio_trashable_qualify_trashed_at(table)} IS NOT NULL"
      end

      private

      def recording_studio_trashable_qualify_trashed_at(table)
        parts = recording_studio_trashable_sql_identifier_parts(table)
        qualified_table = parts.map { |part| connection.quote_table_name(part) }.join(".")
        "#{qualified_table}.#{connection.quote_column_name('trashed_at')}"
      end

      def recording_studio_trashable_sql_identifier_parts(table)
        raise ArgumentError, "table is required" if table.nil?

        parts = table.to_s.split(".", -1)
        return parts if parts.size.between?(1, 2) && parts.all? { |part| part.match?(SQL_IDENTIFIER) }

        raise ArgumentError, "invalid table #{table.inspect}"
      end
    end

    # True when this recording row is soft-trashed. Available on every Recording
    # once the gem is installed (not only on capability-enabled recordables).
    def recording_studio_trashable_trashed?
      trashed_at.present?
    end

    def recording_studio_trashable_kept?
      !recording_studio_trashable_trashed?
    end

    # Soft-void this recording row only: sets `trashed_at` through
    # `update_columns` with no cascade, capability check, authorization, event
    # log, or `trash_root`. Use `recording_studio_trashable_trash!` for
    # user-facing subtree trash.
    def recording_studio_trashable_void!(time: Time.current)
      RecordingStudioTrashable.void_recording!(self, time: time)
    end
  end
end
