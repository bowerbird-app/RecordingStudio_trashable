# frozen_string_literal: true

module RecordingStudioTrashable
  module Api
    module Catalog
      ACTION_VERSION = "1.0.0"
      TAG_SUFFIX = "Trash"
      EMPTY_CONTRACT = { reject_unknown: false, fields: {} }.freeze
      RECORDING_ID_CONTRACT = {
        reject_unknown: false,
        fields: {
          recording_id: {
            type: :string,
            required: false,
            allow_blank: true,
            description: "Id of a trash-bin record in this recording's subtree. Omit it to use the path recording."
          }
        }
      }.freeze
      LIST_TRASH_BIN_CONTRACT = {
        reject_unknown: false,
        fields: {
          q: {
            type: :string,
            required: false,
            allow_blank: true,
            description: "Case-insensitive search on name, title, type, or id."
          },
          page: {
            type: :integer,
            required: false,
            description: "Page number. Starts at 1."
          },
          per_page: {
            type: :integer,
            required: false,
            description: "Page size. Defaults to 25. Maximum 100."
          }
        }
      }.freeze
      UNPROCESSABLE = {
        trashable_trash: "This item is already in the trash.",
        trashable_restore: "This item is not in the trash.",
        trashable_purge: "Purging requires the item to already be in the trash.",
        trashable_list_trash_bin: "Search or page is not valid."
      }.freeze
      TRASH_DESCRIPTION = "Moves this recording into the trash, and moves every recording under it into the trash. " \
                          "Restore can bring that set back. " \
                          "The recording must not already be in the trash. " \
                          "A recording that is already in the trash returns 422. " \
                          "This action only sees kept recordings, so a trashed path recording returns 404. " \
                          "Returns the recording resource."
      RESTORE_DESCRIPTION = "Brings this recording back from the trash, " \
                            "and brings back the recordings that were trashed with it. " \
                            "Recordings trashed on their own stay in the trash, and so does everything under them. " \
                            "The recording must already be in the trash. " \
                            "A recording that is not in the trash returns 422. " \
                            "This cannot undo a purge. " \
                            "Pass recording_id to restore a trash root in this recording's subtree. " \
                            "An id outside that set returns 404. " \
                            "Omit recording_id to restore the path recording. " \
                            "Returns the recording resource."
      PURGE_DESCRIPTION = "Permanently deletes this recording and everything under it. " \
                          "This cannot be undone. " \
                          "The recording must already be in the trash. " \
                          "A recording that is not in the trash returns 422. " \
                          "If a recording under it is still active, nothing is deleted and the request returns 422. " \
                          "Pass recording_id to purge a trash root in this recording's subtree. " \
                          "An id outside that set returns 404. " \
                          "Omit recording_id to purge the path recording. " \
                          "Returns id and purged true."
      LIST_TRASH_BIN_DESCRIPTION = "Lists trash roots in this recording's subtree, newest first. " \
                                   "A trash root is a recording someone trashed directly. " \
                                   "Recordings that are in the trash only because a parent was trashed are omitted. " \
                                   "The path recording is included when it was trashed directly. " \
                                   "Each record id is the recording_id restore and purge accept on this parent. " \
                                   "Optional q matches name, title, type, or id, ignoring case. " \
                                   "page starts at 1. per_page defaults to 25 and stops at 100. " \
                                   "An invalid search or page returns 422. " \
                                   "Order is trashed_at descending, then id descending. " \
                                   "Returns that page of records. " \
                                   "Each record is the recording resource plus label and recordable_type. " \
                                   "The response has no page number and no total. " \
                                   "An empty records array means that page has no rows."
      ACTIONS = {
        trashable_trash: {
          http_verb: :post,
          required_role: :edit,
          handler: Actions::Trash,
          title: "Trash",
          summary: "Move to trash",
          description: TRASH_DESCRIPTION
        }.freeze,
        trashable_restore: {
          http_verb: :post,
          required_role: :edit,
          handler: Actions::Restore,
          title: "Restore",
          summary: "Restore from trash",
          description: RESTORE_DESCRIPTION
        }.freeze,
        trashable_purge: {
          http_verb: :post,
          required_role: :admin,
          handler: Actions::Purge,
          title: "Purge",
          summary: "Delete forever",
          description: PURGE_DESCRIPTION
        }.freeze,
        trashable_list_trash_bin: {
          http_verb: :get,
          required_role: :edit,
          handler: Actions::ListTrashBin,
          title: "List trash bin",
          summary: "List trash in this branch",
          description: LIST_TRASH_BIN_DESCRIPTION
        }.freeze
      }.freeze

      module_function

      def contract_for(name)
        case name
        when :trashable_list_trash_bin
          LIST_TRASH_BIN_CONTRACT
        when :trashable_restore, :trashable_purge
          RECORDING_ID_CONTRACT
        else
          EMPTY_CONTRACT
        end
      end

      def openapi_for(name)
        spec = ACTIONS.fetch(name)
        {
          title: spec.fetch(:title),
          summary: spec.fetch(:summary),
          description: spec.fetch(:description),
          tag_suffix: TAG_SUFFIX,
          responses: responses_for(name, spec.fetch(:summary))
        }
      end

      def type_title(name, phrase)
        return "List #{phrase} trash bin" if name == :trashable_list_trash_bin

        "#{ACTIONS.fetch(name).fetch(:title)} #{phrase}"
      end

      def responses_for(name, summary)
        {
          "200" => { description: "#{summary} succeeded." },
          "401" => { description: "Sign in with an API token to continue." },
          "403" => { description: "This token cannot #{summary.downcase}." },
          "404" => { description: "That item is not in this workspace." },
          "422" => { description: UNPROCESSABLE.fetch(name) }
        }
      end
    end
  end
end
