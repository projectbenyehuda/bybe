class ExternalLinksController < ApplicationController
  before_action :require_user, only: [:propose]
  before_action :require_moderator, only: [:moderate, :approve, :reject, :escalate]

  def moderate
    submitted_scope = ExternalLink.where(status: :submitted)
    @submitted_links = submitted_scope
                         .includes(:linkable)
                         .order(created_at: :desc)
                         .page(params[:page]).per(20)
    @total_count = submitted_scope.count
    @page_title = t('moderate_links.title')
  end

  def approve
    @link = ExternalLink.find(params[:id])
    @link.update!(status: :approved)

    # Send approval email respecting user email preferences
    LinkProposalMailer.send_or_queue(:approved, @link.proposer_email, @link)

    respond_to do |format|
      format.js { render js: "$('#link_#{@link.id}').fadeOut();" }
    end
  end

  def reject
    @link = ExternalLink.find(params[:id])
    moderator_note = params[:note]
    @link.update!(status: :rejected)

    # Send rejection email with note, respecting user email preferences
    LinkProposalMailer.send_or_queue(:rejected, @link.proposer_email, @link, moderator_note)

    respond_to do |format|
      format.js { render js: "$('#link_#{@link.id}').fadeOut();" }
    end
  end

  def escalate
    @link = ExternalLink.find(params[:id])
    @link.update!(status: :escalated)

    respond_to do |format|
      format.js { render js: "$('#link_#{@link.id}').addClass('escalated');" }
    end
  end

  def propose
    # Spam prevention check - ziburit field should be filled
    if params[:ziburit].blank?
      render js: "alert('#{j I18n.t('propose_link.missing_ziburit')}');"
      return
    end

    # Validate required fields
    if params[:url].blank?
      render js: "alert('#{j I18n.t('propose_link.missing_url')}');"
      return
    end

    if params[:linktype].blank?
      render js: "alert('#{j I18n.t('propose_link.missing_linktype')}');"
      return
    end

    if params[:description].blank?
      render js: "alert('#{j I18n.t('propose_link.missing_description')}');"
      return
    end

    # Create the external link with 'submitted' status
    @link = ExternalLink.new(
      url: params[:url],
      linktype: params[:linktype],
      description: params[:description],
      linkable_type: params[:linkable_type],
      linkable_id: params[:linkable_id],
      status: :submitted,
      proposer_id: current_user&.id,
      proposer_email: params[:proposer_email] || current_user&.email
    )

    if @link.save
      render js: <<-JS
        $('#proposeLinkDlg').modal('hide');
        $('#propose_link_form')[0].reset();
        alert('#{j I18n.t('propose_link.success')}');
      JS
    else
      error_msg = @link.errors.full_messages.join(', ')
      render js: "alert('#{j I18n.t('propose_link.error')}: ' + '#{j error_msg}');"
    end
  end

  private

  def require_user
    unless current_user
      render js: "alert('#{I18n.t(:must_login_for_this)}');"
    end
  end

  def require_moderator
    unless current_user&.has_bit?('moderate_links')
      flash[:error] = t(:not_an_editor)
      redirect_to root_path
    end
  end
end
