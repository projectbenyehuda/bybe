# frozen_string_literal: true

# Collection item
class CollectionItem < ApplicationRecord
  belongs_to :collection, inverse_of: :collection_items
  belongs_to :item, polymorphic: true, optional: true

  validates :seqno, presence: true
  validate :ensure_no_cycle

  def title
    if item.nil?
      return alt_title if alt_title.present?

      # return first_contentful_markdown if markdown.present?

      return ''
    else
      item.title
    end
  end

  def authors
    return [] if item.nil?

    item.authors
  end

  def involved_authorities
    return [] if item.nil?

    ret = item.try(:involved_authorities)
    return [] if ret.nil?

    ret
  end

  def involved_authorities_by_role(role)
    involved_authorities.select { |ia| ia.role == role }
  end

  def first_contentful_markdown
    return '' if markdown.blank?

    markdown.split("\n").each do |line|
      return line if line.present?
    end
    ''
  end

  def title_and_authors
    ret = title
    return ret if item.blank?

    if item.authors.present?
      as = item.authors_string
      ret += " #{I18n.t(:by)} #{as}" if as.present?
    elsif item.editors.present?
      ret += " #{I18n.t(:edited_by)} #{item.editors_string}"
    end
    ret
  end

  def title_and_authors_html
    ret = "<h1>#{title}</h1>"
    return ret if item.blank?

    if item.authors.present?
      as = item.authors_string
      ret += "#{I18n.t(:by)}<h2>#{as}</h2>" if as.present?
    elsif item.editors.present?
      ret += "#{I18n.t(:edited_by)} <h2>#{item.editors_string}</h2>"
    end
    ret
  end

  def collection?
    item.is_a?(Collection)
  end

  def genre
    return item.genre if item.present? && item.respond_to?(:genre)

    return 'paratext' if markdown.present?

    return ''
  end

  def public?
    return item.status == 'published' if item.present? && item_type == 'Manifestation'

    return true # placeholders, series, paratexts are always public
  end

  def to_html
    if item.present?
      return item.to_html
    end
    return '' if markdown.blank?

    return MultiMarkdown.new(markdown).to_html
  end

  # return list of genres in included items
  def included_genres
    return [] unless item.present?
    return [item.expression.work.genre] if item_type == 'Manifestation'

    return item.included_genres if item.respond_to?(:included_genres) # sub-collections

    return []
  end

  # return list of copyright statuses in included items
  def intellectual_property_statuses
    return [] unless item.present?
    return [item.expression.intellectual_property] if item_type == 'Manifestation'

    return item.intellectual_property_statuses if item.respond_to?(:intellectual_property_statuses) # sub-collections

    return []
  end

  # return Recommendations for included items
  def included_recommendations
    return [] unless item.present?
    return [item.recommendations] if %w(Manifestation Collection).include?(item_type)

    return item.included_recommendations if item.respond_to?(:included_recommendations) # sub-collections

    return []
  end

  protected

  def ensure_no_cycle
    return unless item.is_a?(Collection)

    return unless given_parent?(item)

    errors.add(:collection, :cycle_found)
  end

  def given_parent?(parent_collection)
    return true if collection == parent_collection

    return collection.parent_collection_items.preload(:collection).any? do |ci|
      ci.given_parent?(parent_collection)
    end
  end
end
