class LexPublicationsController < ApplicationController
  before_action :set_lex_publication, only: %i[ show edit update destroy ]

  # GET /lex_publications or /lex_publications.json
  def index
    @lex_publications = LexPublication.all
  end

  # GET /lex_publications/1 or /lex_publications/1.json
  def show
  end

  # GET /lex_publications/new
  def new
    @lex_publication = LexPublication.new
  end

  # GET /lex_publications/1/edit
  def edit
  end

  # POST /lex_publications or /lex_publications.json
  def create
    @lex_publication = LexPublication.new(lex_publication_params)

    respond_to do |format|
      if @lex_publication.save
        format.html { redirect_to @lex_publication, notice: "Lex publication was successfully created." }
        format.json { render :show, status: :created, location: @lex_publication }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_publication.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_publications/1 or /lex_publications/1.json
  def update
    respond_to do |format|
      if @lex_publication.update(lex_publication_params)
        format.html { redirect_to @lex_publication, notice: "Lex publication was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_publication }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_publication.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_publications/1 or /lex_publications/1.json
  def destroy
    @lex_publication.destroy
    respond_to do |format|
      format.html { redirect_to lex_publications_url, notice: "Lex publication was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_publication
      @lex_publication = LexPublication.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_publication_params
      params.require(:lex_publication).permit(:description, :toc, :az_navbar)
    end
end
