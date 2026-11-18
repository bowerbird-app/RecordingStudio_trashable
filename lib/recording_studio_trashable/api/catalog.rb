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
            description: "Search text you pass. Matches name, title, type, or id."
          },
          page: {
            type: :integer,
            required: false,
            description: "Trash bin page. Starts at 1."
          },
          per_page: {
            type: :integer,
            required: false,
            description: "Items per page. Defaults to 25, same as the trash bin. Capped at 100."
          }
        }
      }.freeze
      UNPROCESSABLE = {
        trashable_trash: "This item is already in the trash.",
        trashable_restore: "This item is not in the trash.",
        trashable_purge: "Purging requires the item to already be in the trash.",
        trashable_list_trash_bin: "Search or page is not valid."
      }.freeze
      TRASH_DESCRIPTION = "Moves this item to the trash. " \
                          "It also moves everything under the item to the trash. " \
                          "Use this when the delete should be recoverable. " \
                          "Restore can undo it. " \
                          "Use Purge after the item is already in the trash, when you want it deleted permanently. " \
                          "Set action to trashable_trash. " \
                          "Pass the recording id of a kept item. " \
                          "Take that id from a list or show of that item. " \
                          "That recording id is the only input. " \
                          "You need the edit role on this item. " \
                          "Returns the recording resource for the item. " \
                          "The fields are id, type, parent_id, root_id, created_at, and updated_at, " \
                          "plus any serializer output keys, fields, and relationships " \
                          "that type's API registration declares. " \
                          "id, parent_id, and root_id are strings. " \
                          "parent_id and root_id are null when the item has no parent or root. " \
                          "created_at and updated_at are ISO 8601 strings. " \
                          "trashed_at is not a field in this JSON. " \
                          "List trash bin records also include label and recordable_type. " \
                          "Restore and Purge can target one of those records with recording_id " \
                          "when called on the parent."
      RESTORE_DESCRIPTION = "Brings this item back from the trash. " \
                            "It also brings back the items that were trashed with it. " \
                            "Nested items that were trashed separately stay trashed, " \
                            "and so does everything under those items. " \
                            "Use this to undo Trash. " \
                            "It cannot undo Purge. " \
                            "Call List trash bin first. " \
                            "Set action to trashable_restore. " \
                            "List trash bin records include label and recordable_type. " \
                            "Pass optional recording_id from one of those records to restore that item " \
                            "when this action is called on the parent. " \
                            "Without recording_id, this restores the item in the path. " \
                            "You need the edit role on this item. " \
                            "When recording_id is set, you also need the edit role on that item. " \
                            "Returns the recording resource for the restored item, with the same fields Trash returns."
      PURGE_DESCRIPTION = "Permanently deletes this trashed item and everything trashed under it. " \
                          "This cannot be undone. " \
                          "It only works on an item that is already in the trash. " \
                          "Use this when you want the item deleted permanently. " \
                          "Restore brings the item back. " \
                          "Trash the item first if it is still active. " \
                          "Call List trash bin first. " \
                          "The id comes from List trash bin. " \
                          "Set action to trashable_purge. " \
                          "List trash bin records include label and recordable_type. " \
                          "Pass optional recording_id from one of those records to purge that item " \
                          "when this action is called on the parent. " \
                          "Without recording_id, this purges the item in the path. " \
                          "You need the admin role on this item. " \
                          "When recording_id is set, you also need the admin role on that item. " \
                          "If something under the item is not in the trash, the purge fails and nothing is deleted. " \
                          "Returns id and purged. " \
                          "purged is true. " \
                          "id is the recording id you passed."
      LIST_TRASH_BIN_DESCRIPTION = "Lists the trash in this item's subtree. " \
                                   "It returns only top-level trashed items, newest first. " \
                                   "A top-level trashed item is one someone trashed directly. " \
                                   "Items that were trashed only because a parent was trashed stay off the list. " \
                                   "This item is included when someone trashed it directly. " \
                                   "Use this to get an id for Restore or Purge. " \
                                   "Set action to trashable_list_trash_bin. " \
                                   "Pass the recording id of the item whose trash you want to see. " \
                                   "Optional q searches name, title, type, or id. " \
                                   "q is the search text you pass. The match ignores case. " \
                                   "Optional page starts at 1. " \
                                   "Optional per_page defaults to 25 and is capped at 100. " \
                                   "Pass q, page, and per_page as the action input. " \
                                   "Ordering is trashed_at descending, then id descending. " \
                                   "You need the edit role on this item. " \
                                   "Returns records for that page. " \
                                   "Each record has the same fields Trash returns, plus label and recordable_type. " \
                                   "label is the title, then the name, " \
                                   "then the type and the first 8 characters of the id. " \
                                   "Restore and Purge can target a record with recording_id " \
                                   "when called on the parent. " \
                                   "The response has no page number and no total count. " \
                                   "Pass the next page number to see more. " \
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
