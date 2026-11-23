# frozen_string_literal: true

module RecordingStudioTrashable
  module McpCopy
    module Copy
      TYPE = "Items of this type can move to the trash and come back. " \
             "Trash also moves everything under the item, so the delete can be undone. " \
             "Purge permanently deletes an item that is already in the trash, and it deletes the children too."

      TRASH = "Moves this item to the trash, and moves everything under it too, so you can bring it back. " \
              "Use this when the delete should be recoverable. " \
              "The item must still be active. " \
              "Restore undoes this. " \
              "Purge permanently deletes an item that is already in the trash."

      RESTORE = "Brings this item back from the trash, and brings back the children that were trashed with it. " \
                "Children that were trashed on their own stay in the trash. " \
                "The item must already be in the trash. " \
                "This cannot undo a purge. " \
                "Pass recording_id from the trash bin list to restore that item when you call this on its parent. " \
                "Leave recording_id out to restore the item you called."

      PURGE = "Permanently deletes this item and everything under it. " \
              "This cannot be undone. " \
              "The item must already be in the trash. " \
              "If something under it is still active, nothing is deleted. " \
              "Trash the item first when it is still active. " \
              "Pass recording_id from the trash bin list to purge that item when you call this on its parent. " \
              "Leave recording_id out to purge the item you called."

      LIST = "Lists the trash in this item's subtree so you can pick an id for restore or purge. " \
             "You get the items someone trashed directly, newest first. " \
             "Items that landed in the trash only because a parent was trashed stay off the list. " \
             "Optional q matches name, title, type, or id. " \
             "page starts at 1. " \
             "per_page defaults to 25 and stops at 100."

      RECORDING_ID = "Id of a trashed item from the trash bin list. " \
                     "Leave this out to use the item you called."

      DESCRIPTIONS = {
        trashable_trash: TRASH,
        trashable_restore: RESTORE,
        trashable_purge: PURGE,
        trashable_list_trash_bin: LIST
      }.freeze

      INPUTS = {
        trashable_trash: {}.freeze,
        trashable_restore: { "recording_id" => { description: RECORDING_ID } }.freeze,
        trashable_purge: { "recording_id" => { description: RECORDING_ID } }.freeze,
        trashable_list_trash_bin: {
          "q" => { description: "Search text. Matches name, title, type, or id." },
          "page" => { description: "Page number. Starts at 1." },
          "per_page" => { description: "Items per page. Defaults to 25 and stops at 100." }
        }.freeze
      }.freeze

      OUTPUTS = {
        trashable_trash: "The item after it moves to the trash.",
        trashable_restore: "The item after it comes back from the trash.",
        trashable_purge: "The id you purged, with purged true.",
        trashable_list_trash_bin: "The trashed items on this page."
      }.freeze
    end
  end
end
