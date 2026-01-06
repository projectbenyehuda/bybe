class ExternalLinksController < ApplicationController
  include ActionView::Helpers::JavaScriptHelper

  before_action :require_user, only: [:propose, :destroy]
  before_action :require_moderator, only: %i(moderate approve reject escalate)

  def moderate
    submitted_scope = ExternalLink.where(status: :submitted)
    @submitted_links = submitted_scope
                       .includes(:linkable)
                       .order(created_at: :desc)
                       .page(params[:page]).per(20)
    @total_count = submitted_scope.count
    @page_title = t('moderate_links.title')

    # Preload proposer track records to avoid N+1 queries
    proposer_ids = @submitted_links.map(&:proposer_id).compact.uniq
    @proposer_stats = calculate_proposer_stats(proposer_ids)
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

  def destroy
    @link = ExternalLink.find(params[:id])

    # Only allow proposer to delete their own pending proposals
    if @link.proposer_id != current_user.id
      render js: "alert('#{j I18n.t(:unauthorized)}');"
      return
    end

    if @link.status != 'submitted'
      render js: "alert('#{j I18n.t(:can_only_cancel_pending_links)}');"
      return
    end

    linkable = @link.linkable
    @link.destroy!

    # Render the updated external links panel
    panel_html = render_to_string(
      partial: 'shared/external_links_panel',
      locals: { linkable: linkable },
      formats: [:html]
    )

    respond_to do |format|
      format.js { render js: "$('#external_links_panel').replaceWith('#{j panel_html}');" }
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
      proposer_id: current_user.id,
      proposer_email: current_user.email
    )

    if @link.save
      # Get the linkable object to pass to the partial
      linkable = @link.linkable

      # Render the updated external links panel
      panel_html = render_to_string(
        partial: 'shared/external_links_panel',
        locals: { linkable: linkable },
        formats: [:html]
      )

      render js: <<-JS
        $('#proposeLinkDlg').modal('hide');
        $('#propose_link_form')[0].reset();
        $('#external_links_panel').replaceWith('#{j panel_html}');
      JS
    else
      error_msg = @link.errors.full_messages.join(', ')
      render js: "alert('#{j I18n.t('propose_link.error')}: ' + '#{j error_msg}');"
    end
  end

  private

  def require_user
    return if current_user

    render js: "alert('#{I18n.t(:must_login_for_this)}');"
  end

  def require_moderator
    return if current_user&.has_bit?('link_moderation')

    flash[:error] = t(:not_an_editor)
    redirect_to root_path
  end

  # Calculate approval statistics for proposers
  # Returns a hash: { proposer_id => { total: X, approved: Y, percentage: Z } }
  def calculate_proposer_stats(proposer_ids)
    return {} if proposer_ids.empty?

    # Get counts grouped by proposer_id and status
    stats = ExternalLink.where(proposer_id: proposer_ids)
                        .group(:proposer_id, :status)
                        .count

    # Transform into the format we need
    proposer_ids.each_with_object({}) do |proposer_id, result|
      approved = stats[[proposer_id, 'approved']] || 0
      rejected = stats[[proposer_id, 'rejected']] || 0
      total_decided = approved + rejected

      result[proposer_id] = {
        total: total_decided,
        approved: approved,
        percentage: total_decided > 0 ? (approved.to_f / total_decided * 100).round(1) : nil
      }
    end
  end
end
