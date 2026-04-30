# frozen_string_literal: true

require_relative "hooks"

module RecordingStudioTrashable
  class Configuration
    DEFAULT_AUTHORIZATION_ROLES = {
      trash: :edit,
      restore: :edit,
      purge: :admin,
      settings: :admin,
      trash_bin: :edit
    }.freeze

    attr_accessor :accessible_integration_enabled,
                  :authorization_resolver,
                  :current_actor_resolver,
                  :current_impersonator_resolver,
                  :mounted_page_authorizer,
                  :full_page_layout,
                  :default_purge_after_days
    attr_reader :hooks

    def initialize
      @accessible_integration_enabled = true
      @authorization_resolver = nil
      @current_actor_resolver = nil
      @current_impersonator_resolver = nil
      @mounted_page_authorizer = nil
      @full_page_layout = nil
      @default_purge_after_days = nil
      @authorization_roles = DEFAULT_AUTHORIZATION_ROLES.dup
      @hooks = Hooks.new
    end

    def authorization_roles=(roles)
      merged = DEFAULT_AUTHORIZATION_ROLES.merge(normalize_hash(roles))
      @authorization_roles = merged.transform_values(&:to_sym)
    end

    def authorization_roles
      @authorization_roles.dup
    end

    def role_for(action)
      @authorization_roles.fetch(action.to_sym) { DEFAULT_AUTHORIZATION_ROLES.fetch(action.to_sym, :edit) }
    end

    def to_h
      {
        accessible_integration_enabled: accessible_integration_enabled,
        authorization_roles: authorization_roles,
        full_page_layout: full_page_layout,
        default_purge_after_days: default_purge_after_days,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        if key.to_s == "authorization_roles"
          self.authorization_roles = value
          next
        end

        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    private

    def normalize_hash(value)
      return {} unless value.respond_to?(:to_h)

      value.to_h.each_with_object({}) do |(key, entry), result|
        result[key.to_sym] = entry
      end
    end
  end
end
