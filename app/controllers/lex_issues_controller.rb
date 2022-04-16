class LexIssuesController < ApplicationController
  before_action :set_lex_issue, only: %i[ show edit update destroy ]

  # GET /lex_issues or /lex_issues.json
  def index
    @lex_issues = LexIssue.all
  end

  # GET /lex_issues/1 or /lex_issues/1.json
  def show
  end

  # GET /lex_issues/new
  def new
    @lex_issue = LexIssue.new
  end

  # GET /lex_issues/1/edit
  def edit
  end

  # POST /lex_issues or /lex_issues.json
  def create
    @lex_issue = LexIssue.new(lex_issue_params)

    respond_to do |format|
      if @lex_issue.save
        format.html { redirect_to @lex_issue, notice: "Lex issue was successfully created." }
        format.json { render :show, status: :created, location: @lex_issue }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @lex_issue.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lex_issues/1 or /lex_issues/1.json
  def update
    respond_to do |format|
      if @lex_issue.update(lex_issue_params)
        format.html { redirect_to @lex_issue, notice: "Lex issue was successfully updated." }
        format.json { render :show, status: :ok, location: @lex_issue }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @lex_issue.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lex_issues/1 or /lex_issues/1.json
  def destroy
    @lex_issue.destroy
    respond_to do |format|
      format.html { redirect_to lex_issues_url, notice: "Lex issue was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lex_issue
      @lex_issue = LexIssue.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_issue_params
      params.require(:lex_issue).permit(:subtitle, :volume, :issue, :seq_num, :toc, :lex_publication_id)
    end
end
