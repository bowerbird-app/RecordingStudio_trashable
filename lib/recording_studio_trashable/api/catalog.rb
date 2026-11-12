# frozen_string_literal: true

module RecordingStudioTrashable
  module Api
    module Catalog
      ACTION_VERSION = "1.0.0"
      EMPTY_CONTRACT = { reject_unknown: false, fields: {} }.freeze
      LIST_TRASH_BIN_CONTRACT = {
        reject_unknown: false,
        fields: {
          q: {
            type: :string,
            required: false,
            allow_blank: true,
            description: "Search trash by name, type, or id"
          },
          limit: {
            type: :integer,
            required: false,
            description: "Maximum number of trash items to return"
          }
        }
      }.freeze
      UNPROCESSABLE = {
        trash: "This item is already in the trash.",
        restore: "This item is not in the trash.",
        purge: "Purging requires the item to already be in the trash.",
        list_trash_bin: "Search or limit is not valid."
      }.freeze
      ACTIONS = {
        trash: {
          http_verb: :post,
          required_role: :edit,
          handler: Actions::Trash,
          title: "Trash - Trash",
          summary: "Move to trash",
          description: "Soft-deletes this item and everything nested under it. Same as Trash on the page."
        }.freeze,
        restore: {
          http_verb: :post,
          required_role: :edit,
          handler: Actions::Restore,
          title: "Trash - Restore",
          summary: "Restore from trash",
          description: "Brings this item back. Nested items that were trashed on their own stay in the trash."
        }.freeze,
        purge: {
          http_verb: :post,
          required_role: :admin,
          handler: Actions::Purge,
          title: "Trash - Purge",
          summary: "Delete forever",
          description: "Permanently deletes this trashed item and its nested trash. Active items must be trashed first."
        }.freeze,
        list_trash_bin: {
          http_verb: :get,
          required_role: :edit,
          handler: Actions::ListTrashBin,
          title: "Trash - List trash bin",
          summary: "List trash in this branch",
          description: "Lists items people moved to trash under this item. Cascade-trashed children stay hidden."
        }.freeze
      }.freeze

      module_function

      def contract_for(name)
        name == :list_trash_bin ? LIST_TRASH_BIN_CONTRACT : EMPTY_CONTRACT
      end

      def openapi_for(name)
        spec = ACTIONS.fetch(name)
        {
          title: spec.fetch(:title),
          summary: spec.fetch(:summary),
          description: spec.fetch(:description),
          responses: responses_for(name, spec.fetch(:summary))
        }
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
