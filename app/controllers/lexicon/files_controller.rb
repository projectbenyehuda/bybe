# frozen_string_literal: true

module Lexicon
  # Controller to manage Lexicon migration from static php files to Ben-Yehuda project
  class FilesController < ApplicationController
    before_action :set_lex_file, only: [:migrate]

    # GET /lex_files or /lex_files.json
    def index
      @lex_files = LexFile.all
      @entrytype = params[:entrytype]

      if @entrytype.present?
        @lex_files = @lex_files.where(entrytype: @entrytype)
      end

      @lex_files = @lex_files.order(:fname).page(params[:page])
    end

    def migrate
      LexEntry.transaction do
        lex_entry =  if @lex_file.entrytype_person?
                       IngestPerson.call(@lex_file)
                     elsif @lex_file.entrytype_text?
                       IngestPublication.call(@lex_file)
                     else
                       raise "unsupported entrytype: #{@lex_file.entrytype}"
                     end
        redirect_to lexicon_entry_path(lex_entry), notice: t('.success')
      end
    end

    private

    def set_lex_file
      @lex_file = LexFile.find(params[:id])
    end
  end
end
