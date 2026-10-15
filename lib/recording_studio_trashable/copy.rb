# frozen_string_literal: true

require "i18n"

module RecordingStudioTrashable
  module Copy
    PREFIX = "recording_studio.trashable"
    UNSET = Object.new.freeze

    module_function

    # Relative keys under recording_studio.trashable.* — English fallback comes
    # from RecordingStudio.t (loaded :en, caller default:, then registered
    # shipped English from this gem's config/locales/en.yml).
    def t(key, **)
      RecordingStudio.t("#{PREFIX}.#{key}", **)
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

    # English action tokens match main's overview <dt> and authorize-error
    # wording. Unknown actions fall back to the raw token (byte-identical).
    def action_name(action)
      name = action.to_s
      t("actions.#{name}", default: name)
    end
  end
end
