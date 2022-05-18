class LexMigrationController < ApplicationController
  def index
  end

  def list_files
    @lex_files = LexFile.all.page(params[:page])
  end

  def analyze_person
    file = LexFile.find(params[:id])
    if file.nil?
      redirect_to action: :index
    else
      @lex_person = LexPerson.analyze(file)
      @title = file.title
    end
  end

  def analyze_text
  end

  def analyze_bib
  end

  def resolve_entry
  end
end
