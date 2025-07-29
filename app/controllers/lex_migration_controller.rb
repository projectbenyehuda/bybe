class LexMigrationController < ApplicationController
  def index
  end

  def list_files
    @lex_files = LexFile.all.page(params[:page])
  end

  def migrate_person
    LexPerson.transaction do
      @lex_entry = Lexicon::IngestPerson.call(params[:id])
      @lex_person = @lex_entry.lex_item
    end
  end
end
