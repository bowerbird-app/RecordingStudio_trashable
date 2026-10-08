# frozen_string_literal: true

require "erb"
require "i18n"

module RecordingStudioTrashable
  module Copy
    PREFIX = "recording_studio.trashable"
    UNSET = Object.new.freeze

    module_function

    def t(key, **options)
      full_key = "#{PREFIX}.#{key}"
      return I18n.t(full_key, **options) unless key.to_s.end_with?("_html")

      escaped = options.transform_values { |value| value.is_a?(String) ? ERB::Util.html_escape(value) : value }
      I18n.t(full_key, **escaped).to_s.html_safe
    end

    def l(object, **)
      I18n.l(object, **)
    end

    def provided?(value)
      !value.equal?(UNSET)
    end

    def value(override, key, **)
      provided?(override) ? override : t(key, **)
    end

    # Host copy that still matches the English default follows the locale.
    # A different string (including blank after presence) is host copy and wins.
    def defaulted(value, default, key, **)
      return t(key, **) if value.nil? || value == default

      value
    end

    def action_name(action)
      name = action.to_s
      t("actions.#{name}", default: name)
    end
  end
end
