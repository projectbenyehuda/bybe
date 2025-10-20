# frozen_string_literal: true

# Citation about lexicon entry

# citations are not first-order entities in the lexicon. They are single-line references to texts about a lexicon
# author or a particular lexicon author's publication.
class LexCitation < ApplicationRecord
  belongs_to :item, polymorphic: true # item this citation is about
  belongs_to :manifestation, optional: true # manifestation representing this citation (if present in BYP)

  # This status column is temporary and should be removed in the future after migration from PHP will be completed
  enum :status,
       {
         raw: 0, # markup copied from PHP file (need to be parsed and splitted into separate columns)
         approved: 1, # markup parsed and stored in separate columns
         manual: 2 # created manually (no raw markup existis)
       }, prefix: true

  validates :raw, absence: true, if: :status_manual?
  validates :raw, presence: true, unless: :status_manual?

  validates :title, :authors, presence: true, if: :status_manual?
end
