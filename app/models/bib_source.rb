# frozen_string_literal: true

class BibSource < ApplicationRecord
  has_many :holdings, dependent: :destroy
  has_many :publications

  # according to the types supported by the Gared gem
  enum :source_type, { aleph: 0, primo: 1, idea: 2, hebrewbooks: 3, googlebooks: 4, nli_api: 5, manual_entry: 6 }
  enum :status, { enabled: 0, disabled: 1 }

  scope :physical_sources, lambda {
    where(status: 'enabled', source_type: [BibSource.source_types[:aleph], BibSource.source_types[:primo], BibSource.source_types[:nli_api], BibSource.source_types[:idea]])
  }
end
