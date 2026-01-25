# frozen_string_literal: true

# Controller to work with Proofs (error reports)
class ProofsController < ApplicationController
  before_action only: %i(index show resolve purge) do |c|
    c.require_editor('handle_proofs')
  end

  before_action :set_proof, only: %i(show resolve)

  def create
    @errors = []
    unless params[:ziburit] =~ /ביאליק/
      @errors << t('.ziburit_failed')
    end

    email = params[:from]
    if email.blank?
      @errors << t('.email_missing')
    end

    if @errors.empty?
      Proof.create!(
        from: email,
        item_id: params.fetch(:item_id),
        item_type: params.fetch(:item_type),
        what: params[:what],
        highlight: params[:highlight],
        status: :new
      )
      head :ok
    else
      render json: @errors, status: :unprocessable_content
    end
  end

  def index
    # calculate tallies
    @count = {
      'all' => Proof.count,
      'new' => Proof.where(status: 'new').count,
      'fixed' => Proof.where(status: 'fixed').count,
      'wontfix' => Proof.where(status: 'wontfix').count,
      'escalated' => Proof.where(status: 'escalated').count,
      'spam' => Proof.where(status: 'spam').count
    }

    @status = params[:status]
    @search_query = params[:search]

    @proofs = if @status.nil?
                # Display all unresolved proofs. We order them by item, so all unresolved proofs
                # about same work could be processed together
                Proof.where.not(status: :spam).order(updated_at: :desc)
              else
                Proof.where(status: @status).order(updated_at: :asc)
              end

    if @search_query.present?
      @proofs = @proofs.where(
        <<~SQL.squish,
          exists (
            select 1 from
              manifestations m
            where
              m.id = proofs.item_id
              and proofs.item_type = 'Manifestation'
              and upper(m.title) like ?
          )
        SQL
        "%#{@search_query.strip.upcase}%"
      )
    end

    @proofs = @proofs.page(params[:page])
  end

  def show
    @proof.what = '' if @proof.what.nil?
  end

  def resolve
    if params[:fixed] == 'yes'
      @proof.status = 'fixed'
      unless params[:email] == 'no' || @proof.from.nil? || @proof.from !~ /\w+@\w+\.\w+/
        explanation = params[:fixed_explanation]
        if @proof.item.is_a?(Manifestation)
          Notifications.send_or_queue(
            :proof_fixed,
            @proof.from,
            @proof,
            manifestation_path(@proof.item),
            @proof.item,
            explanation
          )
        elsif @proof.item.is_a?(Authority)
          Notifications.send_or_queue(
            :proof_fixed,
            @proof.from,
            @proof,
            authority_path(@proof.item),
            @proof.item,
            explanation
          )
        else
          Notifications.send_or_queue(:proof_fixed, @proof.from, @proof, @proof.about, nil, @explanation)
        end
        fix_text = 'תוקן (ונשלח דואל)'
      else
        fix_text = 'תוקן, בלי לשלוח דואל'
      end
    elsif params[:fixed] == 'no'
      if params[:escalate] == 'yes'
        @proof.status = 'escalated'
        fix_text = t(:escalated)
      else
        @proof.status = 'wontfix'
        @explanation = params[:wontfix_explanation]
        unless params[:email] == 'no' || @proof.from.nil? || @proof.from !~ /\w+@\w+\.\w+/
          if @proof.item.is_a?(Manifestation)
            Notifications.send_or_queue(
              :proof_wontfix,
              @proof.from,
              @proof,
              manifestation_path(@proof.item),
              @proof.item,
              @explanation
            )
          elsif @proof.item.is_a?(Authority)
            Notifications.send_or_queue(
              :proof_wontfix,
              @proof.from,
              @proof,
              authority_path(@proof.item),
              @proof.item,
              @explanation
            )
          else
            Notifications.send_or_queue(:proof_wontfix, @proof.from, @proof, @proof.about, nil, @explanation)
          end
          fix_text = 'כבר תקין (ונשלח דואל)'
        else
          fix_text = 'כבר תקין, בלי לשלוח דואל'
        end
      end
    else # spam, just ignore
      @proof.status = 'spam'
      fix_text = 'זבל'
    end
    @proof.resolver = current_user
    @proof.save!
    ListItem.where(listkey: 'proofs_by_user', item_id: @proof.id).destroy_all # unassign the proof from the user's list
    flash[:notice] = t(:resolved_as, fixed: fix_text)
    if current_user.admin?
      redirect_to action: :index, params: { status: :new }
    else
      redirect_to controller: :admin
    end
  end

  def purge
    Proof.where(status: 'spam').delete_all
    flash[:notice] = t(:purged)
    redirect_to action: :index
  end

  private

  def set_proof
    @proof = Proof.find(params[:id])
  end
end
