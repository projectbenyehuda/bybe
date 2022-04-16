class LexPeopleController < ApplicationController
  before_action :set_lex_person, only: %i[ show edit update destroy ]

  # GET /lex_people or /lex_people.json
  def index
    @lex_people = LexPerson.all
  end

  # GET /lex_people/1 or /lex_people/1.json
  def show
  end

  # GET /lex_people/new
  def new
    @lex_person = LexPerson.new
  end

  # GET /lex_people/1/edit
  def edit
  end

  # POST /lex_people or /lex_people.json
  def create
    @lex_person = LexPerson.new(lex_person_params)

    respond_to do |format|
      if @lex_person.save
        format.html { redirect_to @lex_person, notice: "Lex person was successfully created." }
        format.json { render :show, status: :created, location: @lex_person }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_person.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_people/1 or /lex_people/1.json
  def update
    respond_to do |format|
      if @lex_person.update(lex_person_params)
        format.html { redirect_to @lex_person, notice: "Lex person was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_person }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_person.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_people/1 or /lex_people/1.json
  def destroy
    @lex_person.destroy
    respond_to do |format|
      format.html { redirect_to lex_people_url, notice: "Lex person was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_person
      @lex_person = LexPerson.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_person_params
      params.require(:lex_person).permit(:aliases, :copyrighted, :birthdate, :deathdate, :bio, :works, :about)
    end
end
