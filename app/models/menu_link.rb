# == Schema Information
#
# Table name: menu_links
#
#  id            :integer          not null, primary key
#  community_id  :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  sort_priority :integer          default(0)
#  entity_type   :integer          default("for_topbar")
#
# Indexes
#
#  index_menu_links_on_community_and_sort  (community_id,sort_priority)
#

class MenuLink < ApplicationRecord
  has_many :translations, :class_name => "MenuLinkTranslation", :dependent => :destroy
  accepts_nested_attributes_for :translations, allow_destroy: true
  belongs_to :community

  scope :sorted, ->{ order('menu_links.sort_priority ASC') }

  ENTITY_TYPES = {
    for_topbar: 0,
    for_footer: 1
  }.freeze

  enum :entity_type, ENTITY_TYPES

  validates_presence_of :community

  def translation_attributes=(attributes)
    attributes.each do |locale, value|
      if translation = translations.find_by_locale(locale)
        translation.update(value)
      else
        translation = translations.build(value.merge(locale: locale))
      end
    end
  end

  def url(locale)
    TranslationCache.new(self, :translations).translate(locale, :url)
  end

  def title(locale)
    TranslationCache.new(self, :translations).translate(locale, :title)
  end
end
