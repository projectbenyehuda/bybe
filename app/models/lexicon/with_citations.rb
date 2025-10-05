# frozen_string_literal: true

module Lexicon
  module WithCitations
    extend ActiveSupport::Concern

    included do
      has_many :citations, as: :item, class_name: 'LexCitation', dependent: :destroy
    end
  end
end