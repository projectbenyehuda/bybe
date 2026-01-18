class Publication < ApplicationRecord
  belongs_to :authority, inverse_of: :publications
  belongs_to :bib_source
  has_many :holdings, dependent: :destroy
  has_many :list_items, as: :item, dependent: :destroy
  has_one :volume, dependent: :nullify, class_name: 'Collection'
  has_many :lex_person_works, dependent: :nullify
  has_many :lex_citations, through: :lex_person_works, source: :citations_about

  enum :status, { todo: 0, scanned: 1, obtained: 2, uploaded: 3, irrelevant: 4, copyrighted: 5 }

  scope :pubs_to_obtain, ->(source_id) { where(status: 'todo', bib_source_id: source_id) }
  scope :not_uploaded, -> { where.not(status: 'uploaded') }
  scope :maybe_done, -> { joins(:list_items).where(list_items: { listkey: 'pubs_maybe_done' }) }
  scope :not_maybe_done, -> { where.not(id: ListItem.select(:item_id).where(listkey: 'pubs_maybe_done')) }
  scope :false_positive_maybe_done, -> { joins(:list_items).where(list_items: { listkey: 'pubs_false_maybe_done' }) }
  scope :not_false_positive_maybe_done, lambda {
    where.not(id: ListItem.select(:item_id).where(listkey: 'pubs_false_maybe_done'))
  }
  scope :no_volume, -> { where.missing(:volume) }
  scope :has_volume, -> { joins(:volume) }

  after_save :check_lists

  def self.update_publications_that_may_be_done_list
    coll = Publication.not_uploaded.not_maybe_done.not_false_positive_maybe_done.order(:authority_id)
    total = coll.count
    author_title_cache = []
    last_author = nil
    i = 1
    added = 0
    coll.each do |pub|
      print "\nHandling #{i} out of #{total}..." if i % 50 == 0
      if pub.authority_id != last_author
        last_author = pub.authority_id
        author_title_cache = pub.authority.all_works_title_sorted.pluck(:title)
      end
      searchtitle = pub_title_for_comparison(pub.title)
      if author_title_cache.bsearch { |title| searchtitle <=> searchtitle }
        li = ListItem.new(listkey: 'pubs_maybe_done', item: pub)
        li.save!
        added += 1
      end
      i += 1
    end
    puts "...done!\n Added #{added} new maybe_done ListItems."
  end

  def check_lists
    return unless status == 'uploaded'

    lis = list_items.where(listkey: %w(pubs_maybe_done pubs_false_maybe_done))
    lis.destroy_all # remove temporary maintenance list_items once publication is uploaded
  end
end
