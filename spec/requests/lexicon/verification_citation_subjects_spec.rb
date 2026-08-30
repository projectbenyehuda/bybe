# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification citation subject headings', type: :request do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_person) }
  let(:entry) { create(:lex_entry, lex_item: person, status: :verifying) }
  let!(:work) { create(:lex_person_work, person: person, title: 'אור פרא : שירים') }

  describe 'GET /lex/verification/:id/edit_section?section=citation_subjects' do
    let!(:citation) { create(:lex_citation, person: person, subject: 'על "אור פרא"') }

    before { entry.start_verification!('editor@example.com') }

    it 'proposes the work the heading names, without persisting anything' do
      get "/lex/verification/#{entry.id}/edit_section", params: { section: 'citation_subjects' }

      expect(response).to have_http_status(:success)
      expect(assigns(:citation_subject_proposals).map(&:work)).to eq [work]
      expect(citation.reload.person_work).to be_nil
      expect(citation.subject).to eq 'על "אור פרא"'
    end

    it 'records that the auto-match dialog has been opened' do
      expect { get "/lex/verification/#{entry.id}/edit_section", params: { section: 'citation_subjects' } }
        .to change { entry.reload.citation_subjects_verifiable? }.from(false).to(true)
    end
  end

  describe 'PATCH /lex/verification/:id/confirm_citation_subject' do
    let!(:citations) { create_list(:lex_citation, 2, person: person, subject: 'על "אור פרא"') }

    it 'links every citation under the heading to the work and clears the heading' do
      patch "/lex/verification/#{entry.id}/confirm_citation_subject",
            params: { subject: 'על "אור פרא"', work_id: work.id }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['count']).to eq 2
      expect(citations.map { |c| c.reload.person_work }).to all(eq work)
      expect(citations.map { |c| c.reload.subject }).to all(be_nil)
    end

    it 'clears a heading confirmed as general without setting a work' do
      patch "/lex/verification/#{entry.id}/confirm_citation_subject",
            params: { subject: 'על "אור פרא"', work_id: '' }

      expect(response).to have_http_status(:success)
      expect(citations.map { |c| c.reload.person_work }).to all(be_nil)
      expect(citations.map { |c| c.reload.subject }).to all(be_nil)
    end

    it 'leaves the citations alone when the work belongs to someone else' do
      other_work = create(:lex_person_work)

      patch "/lex/verification/#{entry.id}/confirm_citation_subject",
            params: { subject: 'על "אור פרא"', work_id: other_work.id }

      expect(response).to have_http_status(:not_found)
      expect(citations.map { |c| c.reload.subject }).to all(eq 'על "אור פרא"')
    end
  end

  describe 'PATCH /lex/verification/:id/update_checklist' do
    let!(:citation) { create(:lex_citation, person: person, subject: 'על "אור פרא"') }

    before { entry.start_verification!('editor@example.com') }

    it 'refuses to verify the section before the auto-match dialog has been opened' do
      patch "/lex/verification/#{entry.id}/update_checklist",
            params: { path: 'citation_subjects', verified: 'true' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(entry.reload.verification_progress.dig('checklist', 'citation_subjects', 'verified')).to be false
    end

    it 'verifies the section once the dialog has been opened' do
      get "/lex/verification/#{entry.id}/edit_section", params: { section: 'citation_subjects' }

      patch "/lex/verification/#{entry.id}/update_checklist",
            params: { path: 'citation_subjects', verified: 'true' }

      expect(response).to have_http_status(:success)
      expect(entry.reload.verification_progress.dig('checklist', 'citation_subjects', 'verified')).to be true
    end

    it 'verifies the section straight away when no heading is left to resolve' do
      citation.update!(subject: nil)

      patch "/lex/verification/#{entry.id}/update_checklist",
            params: { path: 'citation_subjects', verified: 'true' }

      expect(response).to have_http_status(:success)
      expect(entry.reload.verification_progress.dig('checklist', 'citation_subjects', 'verified')).to be true
    end
  end
end
