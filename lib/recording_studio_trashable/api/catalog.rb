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
            description: "Recording id from a List trash bin record."
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
            description:
              "Search text for this trash list. Matches a recording name, type, or id. " \
              "Use a name or id from an earlier trashable_list_trash_bin result, or a type string. " \
              "Blank or omitted leaves the list unfiltered."
          },
          page: {
            type: :integer,
            required: false,
            description:
              "Page number for this trash list, counting from 1. " \
              "Omit it to get the first page. Must be an integer of 1 or more."
          },
          per_page: {
            type: :integer,
            required: false,
            description:
              "How many trash items to return on this page. " \
              "Omit it to use 25, the same default as the trash bin. " \
              "A value above 100 is capped at 100. Must be an integer of 1 or more."
          }
        }
      }.freeze
      UNPROCESSABLE = {
        trashable_trash: "This item is already in the trash.",
        trashable_restore: "This item is not in the trash.",
        trashable_purge: "Purging requires the item to already be in the trash.",
        trashable_list_trash_bin: "Search or page is not valid."
      }.freeze
      TYPE_TITLES = {
        trashable_trash: "Trash",
        trashable_restore: "Restore",
        trashable_purge: "Purge",
        trashable_list_trash_bin: "List trash bin"
      }.freeze
      ACTIONS = {
        trashable_trash: {
          http_verb: :post,
          required_role: :edit,
          handler: Actions::Trash,
          title: "Trash - Trash",
          summary: "Move this recording to the trash.",
          description:
            "Trash takes this recording out of the live tree without deleting it. Nested recordings " \
            "under it are trashed in the same call. This recording becomes the trash root. Nested " \
            "recordings that were already trashed on their own stay as their own trash roots. Run this " \
            "on a live recording. Pass this recording's id from list, show, or create. A missing id is " \
            "rejected as not found. A recording that is already in the trash is rejected as not found. " \
            "Returns this recording after it is in the trash."
        }.freeze,
        trashable_restore: {
          http_verb: :post,
          required_role: :edit,
          handler: Actions::Restore,
          title: "Trash - Restore",
          summary: "Restore this recording from the trash.",
          description:
            "Restore puts this recording back in the live tree. Nested recordings that were trashed " \
            "only because this one was trashed come back with it. Nested recordings that were trashed " \
            "on their own stay in the trash. Run this on a recording that is already in the trash. " \
            "Pass this recording's id from trashable_list_trash_bin, or from show after it was trashed. " \
            "A missing id is rejected as not found. A recording that is not in the trash is rejected. " \
            "Calling restore again after a successful restore is rejected the same way. Returns this " \
            "recording after it is live again."
        }.freeze,
        trashable_purge: {
          http_verb: :post,
          required_role: :admin,
          handler: Actions::Purge,
          title: "Trash - Purge",
          summary: "Permanently delete this trashed recording.",
          description:
            "Purge permanently deletes this recording and nested trash under it. The records are gone " \
            "and cannot be restored. Run this on a recording that is already in the trash. Pass this " \
            "recording's id from trashable_list_trash_bin. A missing id is rejected as not found. A live " \
            "recording, or nested recordings that are still live, is rejected. After a successful purge, " \
            "another call for the same id is rejected as not found. Returns the id and purged true."
        }.freeze,
        trashable_list_trash_bin: {
          http_verb: :get,
          required_role: :edit,
          handler: Actions::ListTrashBin,
          title: "Trash - List trash bin",
          summary: "List recordings people moved to trash under this recording.",
          description:
            "Lists trash roots in this recording's branch. A trash root is a recording someone moved " \
            "to trash directly. Nested recordings that were only trashed because a parent was trashed " \
            "stay hidden. Run this on the recording whose branch you want to inspect. Pass that " \
            "recording's id from list or show. The branch recording may already be in the trash. A " \
            "missing id is rejected as not found. q, page, or per_page that is not a valid value is " \
            "rejected. Calling list again returns the current page. Returns records, newest trash first."
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

        "#{TYPE_TITLES.fetch(name)} #{phrase}"
      end

      def responses_for(name, summary)
        phrase = summary.to_s.sub(/\.+\z/, "")
        {
          "200" => { description: "#{phrase} succeeded." },
          "401" => { description: "Sign in with an API token to continue." },
          "403" => { description: "This token cannot #{phrase.downcase}." },
          "404" => { description: "That item is not in this workspace." },
          "422" => { description: UNPROCESSABLE.fetch(name) }
        }
      end
    end
  end
end
