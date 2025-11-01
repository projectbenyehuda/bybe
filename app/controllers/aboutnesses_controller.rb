class AboutnessesController < ApplicationController
  before_action :require_editor

  def create
    @ab = Aboutness.new(work_id: params['work_id'], user_id: params['suggested_by'])
    case params['aboutness_type']
    when 'Authority'
      @authority = Authority.find(params['add_authority_topic'])
      @ab.aboutable = @authority
    when 'Work'
      m = Manifestation.find(params['add_work_topic'])
      @ab.aboutable = m.expression.work
    when 'Wikidata'
      @ab.wikidata_qid = params['add_external_topic'][1..-1].to_i
      @ab.wikidata_label = params['wikidata_label']
    end
    @ab.save!
  end

  def remove
    ab = Aboutness.find(params[:id])
    if ab.nil?
      flash[:error] = t(:no_such_item)
    else
      ab.destroy!
      flash[:notice] = t(:deleted_successfully)
    end
    redirect_to manifestation_show_path(params[:manifestation_id])
  end
end
