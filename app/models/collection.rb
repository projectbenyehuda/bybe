# frozen_string_literal: true

# Heterogeneous collection
class Collection < ApplicationRecord
  include TrackingEvents

  SYSTEM_TYPES = %w(uncollected).freeze

  include RecordWithInvolvedAuthorities

  update_index('collections') { self }

  before_save :update_sort_title!
  before_save :norm_dates
  before_save :prevent_uncollected_type_change

  validates :collection_type, presence: true

  belongs_to :publication, optional: true
  belongs_to :toc, optional: true
  has_many :collection_items, -> { order(:seqno) }, inverse_of: :collection, dependent: :destroy
  has_many :inclusions, class_name: 'CollectionItem', as: :item, dependent: :destroy # inclusions of this collection in other collections
  has_many :aboutnesses, as: :aboutable, dependent: :destroy # works that are ABOUT this collection
  # has_many :topics, class_name: 'Aboutness', dependent: :destroy # topics that this work is ABOUT
  has_many :downloadables, as: :object, dependent: :destroy

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings, class_name: 'Tag'
  # TODO: implement
  #  has_many :likings, as: :likeable, dependent: :destroy
  #  has_many :likers, through: :likings, class_name: 'User'

  # convenience methods
  has_many :manifestation_items, through: :collection_items, source: :item, source_type: 'Manifestation'
  has_many :person_items, through: :collection_items, source: :item, source_type: 'Person'
  has_many :work_items, through: :collection_items, source: :item, source_type: 'Work'
  has_many :coll_items, through: :collection_items, source: :item, source_type: 'Collection'

  # enum :status, { published: 0, nonpd: 1, unpublished: 2, deprecated: 3 }

  # series express anything from a cycle of poems to a multi-volume work or a series of detective novels;
  # anthologies are collections of texts by multiple authors, such as festschrifts, almanacs,
  #   or collective anthologies;
  # periodicals are journals, magazines, newspapers, etc., where there is a known sequence of issues;
  # periodical issues are individual issues of a periodical; individual items in a series, such as a single volume in
  #   a multi-volume work, are their appropriate type -- a manifestation if a single text, a collection of type volume
  #   if a book, etc.;
  # other is a catch-all for anything else
  # uncollected is used to group authority's works not belonging to any other collections. Each authority can have one.
  enum :collection_type, {
    volume: 0,
    periodical: 1,
    periodical_issue: 2,
    series: 3,
    other: 5,
    uncollected: 100
  }
  enum :toc_strategy, { default: 0, custom_markdown: 1 } # placeholder for future custom ToC-generation strategies

  # scope :published, -> { where(status: Collection.statuses[:published]) }
  scope :by_type, ->(thetype) { where(collection_type: thetype) }
  scope :by_tag, ->(tag_id) { joins(:taggings).where(taggings: { tag_id: tag_id }) }
  scope :by_authority, lambda { |authority|
                         joins(:involved_authorities).where(involved_authorities: { authority: authority })
                       }

  validates :title, presence: true
  validates :suppress_download_and_print, inclusion: { in: [true, false] }

  # Checks if collection is a system-managed collection. We cannot change type of system collection (maybe some
  # other limitations will be added in future)
  def system?
    SYSTEM_TYPES.include?(collection_type)
  end

  # Allow system operations (like RefreshUncollectedWorksCollection) to bypass type protection
  def allow_system_type_change!
    @allow_system_type_change = true
  end

  def collection_items_by_type(item_type)
    collection_items.where(item_type: item_type)
  end

  def items_by_type(item_type)
    collection_items_by_type(item_type).map(&:item)
  end

  def placeholders
    collection_items.where(item: nil, markdown: nil)
  end

  def title_and_authors
    if authors.present?
      return "#{title} / #{authors_string}"
    elsif editors.present?
      return "#{title} / #{I18n.t(:edited_by)} #{editors_string}"
    else
      return title
    end
  end

  def title_and_authors_html
    ret = "<h1>#{title}</h1>"
    if authors.present?
      as = authors_string
      ret += "#{I18n.t(:by)}<h2>#{as}</h2>" if as.present?
    elsif editors.present?
      es = editors_string
      ret += "#{I18n.t(:edited_by)}<h2>#{es}</h2>" if es.present?
    end
    ret
  end

  def has_multiple_manifestations?
    stack = collection_items.to_a
    manifestation_count = 0

    while stack.any?
      current_item = stack.pop
      if current_item.item_type == 'Manifestation'
        manifestation_count += 1
        return true if manifestation_count > 1
      elsif current_item.item_type == 'Collection' && current_item.item.present?
        stack.concat(current_item.item.collection_items.to_a)
      end
    end

    false
  end

  # produce HTML for a table of contents of the collection - used for periodicals, and skips paratexts
  def toc_html
    ret = '<div class="collection_toc"><ul>'
    flatten_items.each do |ci|
      next if ci.item.nil? && ci.markdown.blank? && ci.alt_title.blank?
      next if ci.paratext # Skip items of type paratext in periodical toc display

      ret += if ci.item.nil? && ci.alt_title.present?
               '<li>' + ci.alt_title
             else
               '<li>' + ci.title_and_authors
             end
    end
    ret += '</div>'
    return ret
  end

  def flatten_items
    ret = []
    collection_items.each do |ci|
      ret << ci
      if ci.item.present? && ci.item.instance_of?(Collection)
        ret += ci.item.flatten_items
      end
    end
    return ret
  end

  # this will return the downloadable entity for the Collection *if* it is fresh
  def fresh_downloadable_for(doctype)
    dl = downloadables.where(doctype: doctype).first
    return nil if dl.nil?

    return nil unless dl.stored_file.attached? # invalid downloadable without file

    return nil if updated_at - dl.updated_at > 1.minute # needs to be re-generated - buffer needed to pass tests

    # also ensure none of the collection items (including sub-collections) is fresher than the saved downloadable
    flatten_items.each do |ci|
      return nil if dl.updated_at < ci.updated_at
      return nil if ci.item.present? && (ci.item.updated_at > dl.updated_at)
    end
    return dl
  end

  def to_html(nonce = '')
    return '' if collection_items.count == 0

    html = title_and_authors_html
    i = 0
    collection_items.each do |ci|
      next if ci.item.nil? && ci.markdown.blank?

      html += '<hr/><p/>' + ci.title_and_authors_html
      inner_nonce = "#{nonce}_#{i}"

      # Wrap Manifestation content with a marker div for proof submission
      if ci.item_type == 'Manifestation' && ci.item.present?
        html += "<div class='nested-manifestation-marker' data-item-id='#{ci.item_id}' data-item-type='Manifestation'>"
        html += footnotes_noncer(ci.to_html, inner_nonce)
        html += '</div>'
      else
        html += footnotes_noncer(ci.to_html, inner_nonce)
      end
      i += 1
    end
    return html
  end

  def authors
    auths = involved_authorities_by_role('author')
    return auths if auths.count > 0

    seen_colls = []
    parent_collections.each do |pc| # iterate until we find authorship
      next if seen_colls.include?(pc.id)

      auths = pc.authors
      return auths if auths.present?

      seen_colls << pc.id
    end

    return []
  end

  def translators
    auths = involved_authorities_by_role('translator')
    return auths if auths.count > 0

    seen_colls = []
    parent_collections.each do |pc| # iterate until we find authorship
      next if seen_colls.include?(pc.id)

      auths = pc.translators
      return auths if auths.present?

      seen_colls << pc.id
    end

    return []
  end

  def editors
    eds = involved_authorities_by_role('editor')
    return eds if eds.count > 0

    seen_colls = []
    parent_collections.each do |pc| # iterate until we find editors
      next if seen_colls.include?(pc.id)

      eds = pc.editors
      return eds if eds.present?

      seen_colls << pc.id
    end

    return []
  end

  def illustrators
    ills = involved_authorities_by_role(:illustrator)
    return ills if ills.count > 0

    seen_colls = []
    parent_collections.each do |pc| # iterate until we find illustrators
      next if seen_colls.include?(pc.id)

      ills = pc.illustrators
      return ills if ills.present?

      seen_colls << pc.id
    end

    return []
  end

  # return true if any of the collection items are original works.
  # This does not traverse sub-collections because it is intended to be used with
  # uncollected works collections, which are expected to be flat, by definition.
  def any_original_works?
    collection_items.each do |ci|
      return true if ci.item.present? && ci.item_type == 'Manifestation' && ci.item.expression.translation == false
    end
    return false
  end

  # return true if any of the collection items are translations
  def any_translations?
    collection_items.each do |ci|
      return true if ci.item.present? && ci.item_type == 'Manifestation' && ci.item.expression.translation
    end
    return false
  end

  # return list of genres in included items
  def included_genres
    genres = []
    collection_items.each do |ci|
      genres += ci.included_genres
    end
    return genres.uniq
  end

  # return list of copyright statuses in included items
  def intellectual_property_statuses
    ips = []
    collection_items.each do |ci|
      ips += ci.intellectual_property_statuses
    end
    return ips.uniq
  end

  # return a list of Recommendations for any included items
  def included_recommendations
    recs = []
    collection_items.each do |ci|
      recs += ci.included_recommendations
    end
    return recs.flatten
  end

  # return true if there are any manifestations that are in status 'published' in this collection or any of its sub-collections, searching breadth-first.
  def any_published_manifestations?
    stack = collection_items.to_a

    while stack.any?
      current_item = stack.pop
      if current_item.item_type == 'Manifestation' && current_item.item.status == 'published'
        return true
      elsif current_item.item_type == 'Collection' && current_item.item.present?
        stack.concat(current_item.item.collection_items.to_a)
      end
    end

    return false
  end

  def like_count
    return 0
    # TODO: enable after implementing the likings table
    # return likers.count
  end

  # TODO: replace with activerecord association
  def recommendations
    return []
  end

  # return nearest parent volume or periodical_issue
  def parent_volume_or_isssue
    seen_colls = []
    parent_collections.each do |pc| # iterate until we find a volume of collection_type parent or periodical_issue
      next if seen_colls.include?(pc.id)

      return pc if pc.volume? || pc.periodical_issue?

      seen_colls << pc.id
    end
    return nil
  end

  def authorities
    auths = involved_authorities
    return auths if auths.count > 0

    seen_colls = []
    parent_collections.each do |pc| # iterate until we find authorship
      next if seen_colls.include?(pc.id)

      auths = pc.authorities
      return auths if auths.present?

      seen_colls << pc.id
    end

    return []
  end

  def authors_string
    ret = authors.map(&:name).join(', ')

    return ret.presence || I18n.t(:nil)
  end

  def before_destroy
    collection_items.each do |ci|
      ci.destroy!
    end
    CollectionItem.where(item: self).each { |ci| ci.destroy! } # destroy all references to this collection
  end

  def collection_items_by_role(role, authority_id)
    collection_items.select do |ci|
      ci.item.present? && ci.item.involved_authorities_by_role(role).any? do |a|
        a.id == authority_id
      end
    end
  end

  def editors_string
    auths = involved_authorities.where(role: 'editor')
    return auths.map(&:authority).map(&:name).join(', ') if auths.count > 0

    parent_collections.each do |pc| # iterate until we find editors
      s = pc.editors_string
      return s if s.present?
    end

    return nil
  end

  def move_item_up(item_id)
    ci = CollectionItem.find(item_id)
    return false if ci.nil?

    prev = collection_items.where('seqno < ?', ci.seqno).last
    return if prev.nil?

    prev.seqno, ci.seqno = ci.seqno, prev.seqno
    prev.save!
    ci.save!
  end

  def move_item_down(item_id)
    ci = CollectionItem.find(item_id)
    return false if ci.nil?

    nxt = collection_items.where('seqno > ?', ci.seqno).first
    return if nxt.nil?

    nxt.seqno, ci.seqno = ci.seqno, nxt.seqno
    nxt.save!
    ci.save!
  end

  def append_item(item)
    ci = collection_item_from_anything(item)
    ci.seqno = collection_items.maximum(:seqno).to_i + 1
    ci.save!
    return ci.id
  end

  def append_collection_item(item)
    item.collection = self
    item.seqno = collection_items.maximum(:seqno).to_i + 1
    item.save!
  end

  def remove_item(item_id)
    raise 'pass an item ID, not an object' if item_id.instance_of?(CollectionItem)

    ci = collection_items.where(id: item_id).first
    return false if ci.nil?

    ci.destroy!
  end

  def fetch_credits
    return cached_credits if cached_credits.present?

    ret = []
    ret += credits.lines if credits.present?
    collection_items.each do |ci|
      next if ci.item.nil?

      ret += ci.item.credits.lines if ci.item.credits.present?
    end
    ret = ret.map(&:strip).uniq.reject(&:empty?)
    self.cached_credits = ret.join("\n")
    save!
    return cached_credits
  end

  def invalidate_cached_credits!
    self.cached_credits = nil
    save!
  end

  # pos is effective 1-based position in the list, not the seqno (which is not necessarily contiguous!)
  def insert_item_at(item, pos)
    Collection.transaction do
      new_seqno = if pos <= 1
                    1
                  elsif pos > collection_items.size
                    collection_items.last.seqno + 1
                  else
                    collection_items[pos - 1].seqno
                  end

      collection_items.where('seqno >= ?', new_seqno).order(:seqno).each do |coli|
        coli.increment!(:seqno)
      end

      @ci = collection_item_from_anything(item)
      @ci.seqno = new_seqno
      @ci.save!
    end
    @ci.id
  end

  def parent_collections
    parent_collection_items.preload(:collection).map(&:collection)
  end

  # returns collection_items where given collection is specified as an item
  def parent_collection_items
    CollectionItem.where(item: self)
  end

  # update status of ALL manifestations included in this collection, including in nested collections
  def change_all_manifestations_status(new_status)
    flatten_items.each do |ci|
      next if ci.item.nil? || ci.item_type != 'Manifestation'

      ci.item.status = new_status
      ci.item.save!
    end
  end

  protected

  def collection_item_from_anything(item)
    # if a string, just create a wrapper item with the string as the alt_title
    if item.instance_of?(String)
      CollectionItem.new(collection: self, alt_title: item)
    elsif item.instance_of?(CollectionItem)
      CollectionItem.new(collection: self, item: item.item, alt_title: item.alt_title, context: item.context,
                         markdown: item.markdown, paratext: item.paratext)
    else
      CollectionItem.new(collection: self, item: item)
    end
  end

  def norm_dates
    nd = normalize_date(pub_year)
    self.normalized_pub_year = nd.year unless nd.nil?
  end

  def prevent_uncollected_type_change
    return true unless collection_type_changed?
    return true if @allow_system_type_change # Allow bypass for system operations

    # Prevent creating new collections with uncollected type (should only be done by RefreshUncollectedWorksCollection)
    if new_record? && uncollected?
      errors.add(:collection_type, :cannot_manually_create_uncollected)
      throw :abort
    end

    # Prevent changing from uncollected to any other type
    if collection_type_was == 'uncollected' && !uncollected?
      errors.add(:collection_type, :cannot_change_from_uncollected)
      throw :abort
    end

    # Prevent changing to uncollected from any other type
    if collection_type_was != 'uncollected' && uncollected?
      errors.add(:collection_type, :cannot_change_to_uncollected)
      throw :abort
    end

    true
  end
end
