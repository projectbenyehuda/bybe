class LexFile < ApplicationRecord
  enum status: {
    unclassified: 0,
    classified: 1,
    ingested: 2,
    approved: 3,
    changed_after_ingestion: 4
  }, _prefix: true
  enum entrytype: {
    unknown: 0,
    person: 1,
    text: 2,
    bib: 3,
    other: 4
  }, _prefix: true

end
