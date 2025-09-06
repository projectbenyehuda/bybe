# frozen_string_literal: true

# Model used to map old lexicon links to new locations in Ben-Yehuda project
class LexLegacyLink < ApplicationRecord
  belongs_to :lex_entry, inverse_of: :legacy_links

  before_validation do
    old_path&.strip!
    old_path&.downcase!
    old_path.gsub!(%r{\Ahttp(s)?://(www\.)?benyehuda.org/lexicon/}, '')
    old_path[1..] if old_path&.start_with?('/')
  end

  validates :old_path, :new_path, presence: true
end
