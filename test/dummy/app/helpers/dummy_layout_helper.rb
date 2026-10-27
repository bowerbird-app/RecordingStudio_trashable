# frozen_string_literal: true

# Host layout helpers. Engine screens also render the forked default layout,
# so this module is included on ActionView, not only ApplicationHelper.
module DummyLayoutHelper
  def dummy_document_attributes
    attributes = { "data-theme" => "rounded", lang: I18n.locale.to_s }
    attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
    return attributes unless respond_to?(:flat_pack_copy_data)

    attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
    attributes
  end

  def dummy_page_nav_back_label
    I18n.exists?("flatpack.page_nav.back") ? I18n.t("flatpack.page_nav.back") : "Go back"
  end

  def dummy_page_nav_close_label
    I18n.exists?("flatpack.page_nav.close") ? I18n.t("flatpack.page_nav.close") : "Close"
  end
end
