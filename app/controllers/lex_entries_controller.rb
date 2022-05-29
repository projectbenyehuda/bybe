class LexEntriesController < ApplicationController
  before_action :set_lex_entry, only: %i[ show edit update destroy ]

  # GET /lex_entries or /lex_entries.json
  def index
    @lex_entries = LexEntry.all
  end

  # GET /lex_entries/1 or /lex_entries/1.json
  def show
    @next_entry = LexEntry.where('sort_title > ?', @lex_entry.sort_title).limit(1).first
    @prev_entry = LexEntry.where('sort_title < ?', @lex_entry.sort_title).limit(1).first
    @header_partial = 'lex_entries/entry_top'
  end

  # GET /lex_entries/new
  def new
    @lex_entry = LexEntry.new
  end

  # GET /lex_entries/1/edit
  def edit
  end

  # POST /lex_entries or /lex_entries.json
  def create
    @lex_entry = LexEntry.new(lex_entry_params)

    respond_to do |format|
      if @lex_entry.save
        format.html { redirect_to @lex_entry, notice: "Lex entry was successfully created." }
        format.json { render :show, status: :created, location: @lex_entry }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_entries/1 or /lex_entries/1.json
  def update
    respond_to do |format|
      if @lex_entry.update(lex_entry_params)
        format.html { redirect_to @lex_entry, notice: "Lex entry was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_entry }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_entries/1 or /lex_entries/1.json
  def destroy
    @lex_entry.destroy
    respond_to do |format|
      format.html { redirect_to lex_entries_url, notice: "Lex entry was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_entry
      @lex_entry = LexEntry.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_entry_params
      params.require(:lex_entry).permit(:title, :status, :lex_person_id, :lex_publication_id)
    end
end
