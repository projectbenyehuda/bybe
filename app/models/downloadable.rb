class Downloadable < ApplicationRecord
  enum :doctype, { pdf: 0, html: 1, docx: 2, epub: 3, mobi: 4, txt: 5, odt: 6, kwic: 7 }
  belongs_to :object, polymorphic: true
  has_one_attached :stored_file # ActiveStorage
end
