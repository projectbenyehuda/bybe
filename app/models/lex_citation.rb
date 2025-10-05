# frozen_string_literal: true

# Citation about lexicon entry

# citations are not first-order entities in the lexicon. They are single-line references to texts about a lexicon
# author or a particular lexicon author's publication.

class LexCitation < ApplicationRecord
  belongs_to :item, polymorphic: true # item this citation is about
  belongs_to :manifestation, optional: true # manifestation representing this citation (if present in BYP)
end
