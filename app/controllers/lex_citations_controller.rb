class LexCitationsController < ApplicationController
  before_action :set_lex_citation, only: %i[ show edit update destroy ]

  # GET /lex_citations or /lex_citations.json
  def index
    @lex_citations = LexCitation.all
  end

  # GET /lex_citations/1 or /lex_citations/1.json
  def show
  end

  # GET /lex_citations/new
  def new
    @lex_citation = LexCitation.new
  end

  # GET /lex_citations/1/edit
  def edit
  end

  # POST /lex_citations or /lex_citations.json
  def create
    @lex_citation = LexCitation.new(lex_citation_params)

    respond_to do |format|
      if @lex_citation.save
        format.html { redirect_to @lex_citation, notice: "Lex citation was successfully created." }
        format.json { render :show, status: :created, location: @lex_citation }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_citation.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_citations/1 or /lex_citations/1.json
  def update
    respond_to do |format|
      if @lex_citation.update(lex_citation_params)
        format.html { redirect_to @lex_citation, notice: "Lex citation was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_citation }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_citation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_citations/1 or /lex_citations/1.json
  def destroy
    @lex_citation.destroy
    respond_to do |format|
      format.html { redirect_to lex_citations_url, notice: "Lex citation was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_citation
      @lex_citation = LexCitation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_citation_params
      params.require(:lex_citation).permit(:title, :from_publication, :authors, :pages, :link, :item_id, :item_type, :manifestation_id)
    end
end
