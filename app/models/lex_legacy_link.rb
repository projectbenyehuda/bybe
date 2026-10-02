# frozen_string_literal: true

# Model used to map old lexicon links to new locations in Ben-Yehuda project
class LexLegacyLink < ApplicationRecord
  belongs_to :lex_entry, inverse_of: :legacy_links

  before_validation do
    self.old_path = LexLegacyLink.normalize_path(old_path)
  end

  validates :old_path, :new_path, presence: true

  def self.find_existing(old_path)
    find_by(old_path: normalize_path(old_path))
  end

  def self.normalize_path(path)
    path = path&.strip
    path&.downcase!
    path&.gsub!(%r{\Ahttp(s)?://(www\.)?#{Lexicon::OLD_LEXICON_PATH}/}, '')
    path = path[1..] if path&.start_with?('/')
    path
  end
end
