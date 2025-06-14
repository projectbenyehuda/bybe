class LexMigrationController < ApplicationController
  def index
  end

  def list_files
    @lex_files = LexFile.all.page(params[:page])
  end

  def migrate_person
    if params[:id].blank?
      redirect_to action: :list_files, notice: 'No file selected for migration.'
      return
    end
    file = LexFile.find(params[:id])
    if file.nil?
      redirect_to action: :index
    else
      @lex_entry = LexEntry.new(title: file.title, sort_title: file.title.strip_nikkud.tr('-־[]()*"\'', '').strip,
                                status: :raw)
      @lex_entry.save!
      file.lex_entry = @lex_entry
      file.status_ingested!
      @lex_person = LexPerson.create_from_html(@lex_entry, file)
      @lex_entry.lex_item = @lex_person
      @lex_entry.save
    end
  end

  def analyze_text
  end

  def analyze_bib
  end

  def resolve_entry
  end
end
