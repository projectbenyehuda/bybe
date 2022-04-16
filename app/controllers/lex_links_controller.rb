class LexLinksController < ApplicationController
  before_action :set_lex_link, only: %i[ show edit update destroy ]

  # GET /lex_links or /lex_links.json
  def index
    @lex_links = LexLink.all
  end

  # GET /lex_links/1 or /lex_links/1.json
  def show
  end

  # GET /lex_links/new
  def new
    @lex_link = LexLink.new
  end

  # GET /lex_links/1/edit
  def edit
  end

  # POST /lex_links or /lex_links.json
  def create
    @lex_link = LexLink.new(lex_link_params)

    respond_to do |format|
      if @lex_link.save
        format.html { redirect_to @lex_link, notice: "Lex link was successfully created." }
        format.json { render :show, status: :created, location: @lex_link }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_link.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_links/1 or /lex_links/1.json
  def update
    respond_to do |format|
      if @lex_link.update(lex_link_params)
        format.html { redirect_to @lex_link, notice: "Lex link was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_link }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_link.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_links/1 or /lex_links/1.json
  def destroy
    @lex_link.destroy
    respond_to do |format|
      format.html { redirect_to lex_links_url, notice: "Lex link was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_link
      @lex_link = LexLink.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_link_params
      params.require(:lex_link).permit(:url, :description, :status, :item_id, :item_type)
    end
end
