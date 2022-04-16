class LexTextsController < ApplicationController
  before_action :set_lex_text, only: %i[ show edit update destroy ]

  # GET /lex_texts or /lex_texts.json
  def index
    @lex_texts = LexText.all
  end

  # GET /lex_texts/1 or /lex_texts/1.json
  def show
  end

  # GET /lex_texts/new
  def new
    @lex_text = LexText.new
  end

  # GET /lex_texts/1/edit
  def edit
  end

  # POST /lex_texts or /lex_texts.json
  def create
    @lex_text = LexText.new(lex_text_params)

    respond_to do |format|
      if @lex_text.save
        format.html { redirect_to @lex_text, notice: "Lex text was successfully created." }
        format.json { render :show, status: :created, location: @lex_text }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_text.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_texts/1 or /lex_texts/1.json
  def update
    respond_to do |format|
      if @lex_text.update(lex_text_params)
        format.html { redirect_to @lex_text, notice: "Lex text was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_text }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_text.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_texts/1 or /lex_texts/1.json
  def destroy
    @lex_text.destroy
    respond_to do |format|
      format.html { redirect_to lex_texts_url, notice: "Lex text was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_text
      @lex_text = LexText.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_text_params
      params.require(:lex_text).permit(:title, :authors, :pages, :lex_publication_id, :lex_issue_id, :manifestation_id)
    end
end
