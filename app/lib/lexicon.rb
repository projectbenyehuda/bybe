# frozen_string_literal: true

module Lexicon
  OLD_LEXICON_PATH = ENV.fetch('OLD_LEXICON_PATH', 'benyehuda.org/lexicon').freeze
  OLD_LEXICON_URL = "https://#{OLD_LEXICON_PATH}".freeze
end
