# frozen_string_literal: true

module RecordingStudioTrashable
  module Api
    module ActionCopy
      ACTIONS = {
        trashable_trash: {
          title: "Trash",
          summary: "Move this recording to the trash.",
          description:
            "Trash takes this recording out of the live tree without deleting it, so Restore can bring it back. " \
            "Nested recordings under it are trashed in the same call. This recording becomes the trash root. Nested " \
            "recordings that were already trashed on their own stay as their own trash roots. Use this when the " \
            "delete should be recoverable. Use Purge after the recording is already in the trash, when you want it " \
            "deleted permanently. Run this on a live recording. Pass this recording's id from list, show, or create. " \
            "A missing id is rejected as not found. A recording that is already in the trash is rejected as not " \
            "found. Calling trash again after a successful trash is rejected the same way. Returns this recording " \
            "after it is in the trash. The fields are id, type, parent_id, root_id, created_at, and updated_at, plus " \
            "any serializer output keys, fields, and relationships that type's API registration declares. id, " \
            "parent_id, and root_id are strings. parent_id and root_id are null when the recording has no parent or " \
            "root. created_at and updated_at are ISO 8601 strings. trashed_at is not a field in this JSON. List " \
            "trash bin records also include label and recordable_type. Restore and Purge can target one of those " \
            "records with recording_id when called on the parent."
        }.freeze,
        trashable_restore: {
          title: "Restore",
          summary: "Restore this recording from the trash.",
          description:
            "Restore puts this recording back in the live tree. Nested recordings that were trashed only because " \
            "this one was trashed come back with it. Nested recordings that were trashed on their own stay in the " \
            "trash, and so does everything under those recordings. Use this to undo Trash. It cannot undo Purge. " \
            "Call List trash bin first. List trash bin records include label and recordable_type. Pass optional " \
            "recording_id from one of those records to restore that recording when this action is called on the " \
            "parent. The recording_id needs to belong under this recording. Without recording_id, this restores the " \
            "recording in the path. Run this on a recording that is already in the trash. Pass this recording's id " \
            "from List trash bin, or from show after it was trashed. A missing id is rejected as not found. A " \
            "recording_id that is not a trash root under this recording is rejected as not found. A recording that " \
            "is not in the trash is rejected. Calling restore again after a successful restore is rejected the same " \
            "way. Returns this recording after it is live again, with the same fields Trash returns."
        }.freeze,
        trashable_purge: {
          title: "Purge",
          summary: "Permanently delete this trashed recording.",
          description:
            "Purge permanently deletes this recording and nested trash under it. The records are gone and cannot be " \
            "restored. It only works on a recording that is already in the trash. Use this when you want the " \
            "recording deleted permanently. Restore brings the recording back. Trash the recording first if it is " \
            "still live. Call List trash bin first. The id comes from List trash bin. List trash bin records include " \
            "label and recordable_type. Pass optional recording_id from one of those records to purge that recording " \
            "when this action is called on the parent. The recording_id needs to belong under this recording. " \
            "Without recording_id, this purges the recording in the path. Run this on a recording that is already in " \
            "the trash. A missing id is rejected as not found. A recording_id that is not a trash root under this " \
            "recording is rejected as not found. A live recording, or nested recordings that are still live, is " \
            "rejected. After a successful purge, another call for the same id is rejected as not found. Returns the " \
            "id and purged true. id is the recording id you passed."
        }.freeze,
        trashable_list_trash_bin: {
          title: "List trash bin",
          summary: "List recordings people moved to trash under this recording.",
          description:
            "Lists trash roots in this recording's branch so you can get an id for Restore or Purge. A trash root " \
            "is a recording someone moved to trash directly. Nested recordings that were only trashed because a " \
            "parent was trashed stay hidden. This recording is included when someone trashed it directly. Run this " \
            "on the recording whose branch you want to inspect. Pass that recording's id from list or show. The " \
            "branch recording may already be in the trash. A missing id is rejected as not found. Optional q " \
            "searches name, title, type, or id. The match ignores case. Optional page starts at 1. Optional per_page " \
            "defaults to 25 and is capped at 100. Pass q, page, and per_page as the action input. page or per_page " \
            "that is not an integer of 1 or more is rejected. Ordering is trashed_at descending, then id " \
            "descending. Calling list again returns the current page. Returns records for that page. Each record has " \
            "the same fields Trash returns, plus label and recordable_type. label is the title, then the name, then " \
            "the type and the first 8 characters of the id. Restore and Purge can target a record with recording_id " \
            "when called on the parent. The response has no page number and no total count. Pass the next page " \
            "number to see more. An empty records array means that page has no rows."
        }.freeze
      }.freeze

      RECORDING_ID_FIELDS = {
        recording_id: {
          type: :string,
          required: false,
          allow_blank: true,
          description:
            "Recording id of one List trash bin record. Optional. Pass it to restore or purge that nested trash " \
            "root when this action is called on the parent. The id needs to belong under this recording. Omit it, " \
            "or pass blank, to act on the recording in the path."
        }
      }.freeze

      LIST_TRASH_BIN_FIELDS = {
        q: {
          type: :string,
          required: false,
          allow_blank: true,
          description:
            "Search text for this trash list. Matches a recording name, title, type, or id. The match ignores " \
            "case. Use a name, title, or id from an earlier List trash bin result, or a type string. Blank or " \
            "omitted leaves the list unfiltered."
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
      }.freeze

      UNPROCESSABLE = {
        trashable_trash: "This item is already in the trash.",
        trashable_restore: "This item is not in the trash.",
        trashable_purge: "Purging requires the item to already be in the trash.",
        trashable_list_trash_bin: "Search or page is not valid."
      }.freeze
    end
  end
end
