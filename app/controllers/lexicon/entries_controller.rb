# frozen_string_literal: true

module Lexicon
  # Controller to render list of all Lexicon entries
  class EntriesController < ApplicationController
    def index
      @lex_entries = LexEntry.all.page(params[:page])
    end
  end
end
