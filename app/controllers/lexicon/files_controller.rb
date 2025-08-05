# frozen_string_literal: true

module Lexicon
  # Controller to manage Lexicon migration from static php files to Ben-Yehuda project
  class FilesController < ApplicationController
    # GET /lex_files or /lex_files.json
    def index
      @lex_files = LexFile.all.page(params[:page])
    end

    def migrate_person
      LexPerson.transaction do
        @lex_entry = Lexicon::IngestPerson.call(params[:id])
        @lex_person = @lex_entry.lex_item
      end
    end
  end
end
