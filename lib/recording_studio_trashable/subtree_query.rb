# frozen_string_literal: true

module RecordingStudioTrashable
  module SubtreeQuery
    SEARCHABLE_RECORDABLE_COLUMNS = %w[title name].freeze

    class << self
      def recordings_for(root_recording, include_root: true)
        return [] unless root_recording

        recordings = include_root ? [root_recording] : []
        frontier = [root_recording.id]

        until frontier.empty?
          children = child_recordings_for(frontier)
          recordings.concat(children)
          frontier = children.map(&:id)
        end

        recordings
      end

      def trashed_recordings_for(root_recording)
        trashed_recordings_for_query(root_recording).to_a
      end

      def trashed_recordings_for_query(root_recording, query: nil)
        relation = trashed_recordings_relation_for(root_recording)
        return relation if normalized_query(query).blank?

        apply_search(relation, normalized_query(query))
      end

      private

      def trashed_recordings_relation_for(root_recording)
        return recording_model.none unless root_recording

        base_relation = recording_model.recording_studio_trashable_trash_roots
                                       .reorder(trashed_at: :desc, updated_at: :desc)

        base_relation.where(id: root_recording.id)
                     .or(base_relation.where(root_recording_id: root_recording.id))
      end

      def apply_search(relation, query) = relation.where(search_sql(relation, query))

      def search_sql(relation, query)
        connection = recording_model.connection
        quoted_query = connection.quote("%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%")
        clauses = [
          "LOWER(#{qualified_recording_column('recordable_type')}) LIKE #{quoted_query}",
          "CAST(#{qualified_recording_column('id')} AS TEXT) LIKE #{quoted_query}",
          *recordable_search_clauses(relation, quoted_query)
        ]

        clauses.join(" OR ")
      end

      def recordable_search_clauses(relation, quoted_query)
        relation.unscope(:order)
                .distinct
                .pluck(:recordable_type)
                .compact
                .filter_map { |recordable_type| recordable_search_clause(recordable_type, quoted_query) }
      end

      def recordable_search_clause(recordable_type, quoted_query)
        recordable_class = recordable_type.safe_constantize
        matching_columns = searchable_columns_for(recordable_class)
        return unless matching_columns

        recordable_exists_clause(recordable_type, recordable_class, matching_columns, quoted_query)
      end

      def child_recordings_for(frontier)
        RecordingStudio::Recording
          .recording_studio_trashable_including_trashed
          .where(parent_recording_id: frontier)
          .reorder(created_at: :asc)
          .to_a
      end

      def searchable_columns_for(recordable_class)
        return unless searchable_recordable_class?(recordable_class)

        matching_columns = SEARCHABLE_RECORDABLE_COLUMNS & recordable_class.column_names
        matching_columns if matching_columns.any?
      end

      def recordable_exists_clause(recordable_type, recordable_class, matching_columns, quoted_query)
        table_name = quote_table(recordable_class.table_name)
        primary_key = quote_column(recordable_class.primary_key)
        column_match_sql = column_match_clause(table_name, matching_columns, quoted_query)

        "(#{recordable_type_match_clause(recordable_type)} " \
          "AND EXISTS (SELECT 1 FROM #{table_name} WHERE #{table_name}.#{primary_key} = " \
          "#{qualified_recording_column('recordable_id')} AND (#{column_match_sql})))"
      end

      def recordable_type_match_clause(recordable_type)
        quoted_type = recording_model.connection.quote(recordable_type)
        "#{qualified_recording_column('recordable_type')} = #{quoted_type}"
      end

      def column_match_clause(table_name, matching_columns, quoted_query)
        matching_columns.map do |column_name|
          "LOWER(CAST(#{table_name}.#{quote_column(column_name)} AS TEXT)) LIKE #{quoted_query}"
        end.join(" OR ")
      end

      def searchable_recordable_class?(recordable_class)
        recordable_class.present? &&
          recordable_class.respond_to?(:table_name) &&
          recordable_class.respond_to?(:column_names) &&
          recordable_class.primary_key.present?
      end

      def qualified_recording_column(column_name)
        "#{quote_table(recording_model.table_name)}.#{quote_column(column_name)}"
      end

      def quote_table(table_name) = recording_model.connection.quote_table_name(table_name)

      def quote_column(column_name) = recording_model.connection.quote_column_name(column_name)

      def normalized_query(query) = query.to_s.strip

      def recording_model = RecordingStudio::Recording
    end
  end
end
