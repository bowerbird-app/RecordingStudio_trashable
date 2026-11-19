# frozen_string_literal: true

require_relative "action_copy"

module RecordingStudioTrashable
  module Api
    module Catalog
      ACTION_VERSION = "1.0.0"
      TAG_SUFFIX = "Trash"
      EMPTY_CONTRACT = { reject_unknown: false, fields: {} }.freeze
      RECORDING_ID_CONTRACT = {
        reject_unknown: false,
        fields: ActionCopy::RECORDING_ID_FIELDS
      }.freeze
      LIST_TRASH_BIN_CONTRACT = {
        reject_unknown: false,
        fields: ActionCopy::LIST_TRASH_BIN_FIELDS
      }.freeze
      UNPROCESSABLE = ActionCopy::UNPROCESSABLE
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
          **ActionCopy::ACTIONS.fetch(:trashable_trash)
        }.freeze,
        trashable_restore: {
          http_verb: :post,
          required_role: :edit,
          handler: Actions::Restore,
          **ActionCopy::ACTIONS.fetch(:trashable_restore)
        }.freeze,
        trashable_purge: {
          http_verb: :post,
          required_role: :admin,
          handler: Actions::Purge,
          **ActionCopy::ACTIONS.fetch(:trashable_purge)
        }.freeze,
        trashable_list_trash_bin: {
          http_verb: :get,
          required_role: :edit,
          handler: Actions::ListTrashBin,
          **ActionCopy::ACTIONS.fetch(:trashable_list_trash_bin)
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
