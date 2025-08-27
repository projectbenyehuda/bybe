# frozen_string_literal: true

module Lexicon
  # Controller to manage Lexicon migration from static php files to Ben-Yehuda project
  class FilesController < ApplicationController
    # GET /lex_files or /lex_files.json
    def index
      @lex_files = LexFile.all
      @entrytype = params[:entrytype]

      if @entrytype.present?
        @lex_files = @lex_files.where(entrytype: @entrytype)
      end

      @lex_files = @lex_files.order(:fname).page(params[:page])
    end

    def migrate_person
      LexPerson.transaction do
        lex_entry = Lexicon::IngestPerson.call(params[:id])
        redirect_to lexicon_person_path(lex_entry.lex_item), notice: t('.success')
      end
    end

    def migrate_publication
      LexPublication.transaction do
        lex_entry = Lexicon::IngestPublication.call(params[:id])
        redirect_to lexicon_publication_path(lex_entry.lex_item), notice: t('.success')
      end
    end
  end
end
