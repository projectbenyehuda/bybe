class LexFilesController < ApplicationController
  before_action :set_lex_file, only: %i[ show edit update destroy ]

  # GET /lex_files or /lex_files.json
  def index
    @lex_files = LexFile.all
  end

  # GET /lex_files/1 or /lex_files/1.json
  def show
  end

  # GET /lex_files/new
  def new
    @lex_file = LexFile.new
  end

  # GET /lex_files/1/edit
  def edit
  end

  # POST /lex_files or /lex_files.json
  def create
    @lex_file = LexFile.new(lex_file_params)

    respond_to do |format|
      if @lex_file.save
        format.html { redirect_to @lex_file, notice: "Lex file was successfully created." }
        format.json { render :show, status: :created, location: @lex_file }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_file.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_files/1 or /lex_files/1.json
  def update
    respond_to do |format|
      if @lex_file.update(lex_file_params)
        format.html { redirect_to @lex_file, notice: "Lex file was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_file }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_file.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_files/1 or /lex_files/1.json
  def destroy
    @lex_file.destroy
    respond_to do |format|
      format.html { redirect_to lex_files_url, notice: "Lex file was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_file
      @lex_file = LexFile.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_file_params
      params.require(:lex_file).permit(:fname, :status, :title, :entrytype, :comments)
    end
end
