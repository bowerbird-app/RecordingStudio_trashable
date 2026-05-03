# frozen_string_literal: true

require_relative "hooks"

module RecordingStudioTrashable
  class Configuration
    DEFAULTS = {
      use_recording_studio_accessible: true,
      authorization_resolver: nil,
      current_actor_resolver: nil,
      current_impersonator_resolver: nil,
      retention_purge_actor_resolver: nil,
      retention_purge_impersonator_resolver: nil,
      mounted_page_authorizer: nil,
      full_page_layout: nil,
      default_purge_after_days: nil,
      allow_user_retention_settings: false
    }.freeze

    DEFAULT_AUTHORIZATION_ROLES = {
      trash: :edit,
      restore: :edit,
      purge: :admin,
      settings: :admin,
      trash_bin: :edit
    }.freeze

    attr_accessor :use_recording_studio_accessible,
                  :authorization_resolver,
                  :current_actor_resolver,
                  :current_impersonator_resolver,
                  :retention_purge_actor_resolver,
                  :retention_purge_impersonator_resolver,
                  :mounted_page_authorizer,
                  :full_page_layout,
                  :default_purge_after_days,
                  :allow_user_retention_settings
    attr_reader :hooks

    def initialize
      DEFAULTS.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
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
      configuration_values.merge(hooks_registered: hooks_registered)
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

    def configuration_values
      {
        use_recording_studio_accessible: use_recording_studio_accessible,
        authorization_roles: authorization_roles,
        full_page_layout: full_page_layout,
        default_purge_after_days: default_purge_after_days,
        allow_user_retention_settings: allow_user_retention_settings,
        retention_purge_actor_resolver: retention_purge_actor_resolver,
        retention_purge_impersonator_resolver: retention_purge_impersonator_resolver
      }
    end

    def hooks_registered
      hooks.instance_variable_get(:@registry).transform_values(&:size)
    end

    def normalize_hash(value)
      return {} unless value.respond_to?(:to_h)

      value.to_h.transform_keys(&:to_sym)
    end
  end
end
