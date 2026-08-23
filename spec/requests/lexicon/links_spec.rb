# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/links' do
  before do
    login_as_lexicon_editor
  end

  let(:entry) { create(:lex_entry, :person) }
  let(:person) { entry.lex_item }

  let!(:links) { create_list(:lex_link, 3, item: person) }

  let(:link) { links.first }

  describe 'GET /lexicon/entries/:ID/links' do
    subject(:call) { get "/lex/entries/#{entry.id}/links" }

    it { is_expected.to eq(200) }
  end

  describe 'GET /lexicon/entries/:ID/links/new' do
    subject(:call) { get "/lex/entries/#{entry.id}/links/new" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/entries/:ID/links' do
    subject(:call) { post "/lex/entries/#{entry.id}/links", params: { lex_link: link_params }, xhr: true }

    context 'when valid params' do
      let(:link_params) { attributes_for(:lex_link).except(:item) }

      it 'creates new record' do
        expect { call }.to change { person.links.count }.by(1)
        expect(call).to eq(200)

        created_link = LexLink.last
        expect(created_link).to have_attributes(link_params)
      end
    end

    context 'when invalid params' do
      let(:link_params) { attributes_for(:lex_link, url: '') }

      it 're-renders new form' do
        expect { call }.not_to(change { person.links.count })
        expect(call).to eq(422)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'GET /lexicon/links/:id/edit' do
    subject(:call) { get "/lex/links/#{link.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /lex/links/:id' do
    subject(:call) { patch "/lex/links/#{link.id}", params: { lex_link: link_params }, xhr: true }

    context 'when valid params' do
      let(:link_params) { attributes_for(:lex_link) }

      before do
        # attributes_for changes the URL, which now triggers a synchronous re-check.
        # Stub the network call so this example stays offline.
        allow(Lexicon::CheckExternalLinks).to receive(:new)
          .and_return(instance_double(Lexicon::CheckExternalLinks, check_url: link_check_result(200)))
      end

      it 'updates record' do
        expect(call).to eq(200)
        expect(link.reload).to have_attributes(link_params.except(:item))
      end
    end

    context 'when invalid params' do
      let(:link_params) { attributes_for(:lex_link, url: '') }

      it 're-renders edit form' do
        expect(call).to eq(422)
        expect(call).to render_template(:edit)
      end
    end

    context 'when the URL is changed' do
      let(:checker) { instance_double(Lexicon::CheckExternalLinks) }
      let(:link_params) { { url: 'https://new.example.com/' } }

      before do
        allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)
        # The link starts out broken, so correcting it now files a Monday report.
        # Stubbed so these examples never reach the real board (see the dedicated context below).
        allow(Lexicon::MondayReport).to receive(:call).and_return({ success: true })
        link.update_columns(http_status: 403, checked_at: 1.day.ago)
      end

      context 'when the new link is accessible' do
        before { allow(checker).to receive(:check_url).and_return(link_check_result(200)) }

        it 'launches a fresh check and stores the new status' do
          call
          expect(checker).to have_received(:check_url).with('https://new.example.com/')
          expect(link.reload.http_status).to eq(200)
          expect(link).not_to be_broken
        end

        it 'includes a success toast in the response' do
          call
          expect(response.body).to include('showToast')
          expect(response.body).to include('success')
        end
      end

      context 'when the new link is still broken' do
        before { allow(checker).to receive(:check_url).and_return(link_check_result(404)) }

        it 'stores the new broken status' do
          call
          expect(link.reload.http_status).to eq(404)
          expect(link).to be_broken
        end
      end

      context 'when the link is unreachable (host defunct)' do
        before { allow(checker).to receive(:check_url).and_return(link_check_result(nil)) }

        it 'stores nil status but records the check time and flags it broken' do
          call
          link.reload
          expect(link.http_status).to be_nil
          expect(link.checked_at).to be_present
          expect(link).to be_broken
        end
      end

      # A bot challenge is not a verdict, so the editor gets a neutral warning rather than
      # a red "still broken" toast. See by-9jz.
      context 'when the new host answers with a bot challenge' do
        before { allow(checker).to receive(:check_url).and_return(link_check_result(403, unverifiable: true)) }

        it 'flags the link unverifiable instead of broken' do
          call
          link.reload
          expect(link.unverifiable).to be true
          expect(link.http_status).to eq(403)
          expect(link).not_to be_broken
        end

        it 'includes a neutral warning toast in the response' do
          call
          expect(response.body).to include('warning')
          expect(response.body).to include(I18n.t('lexicon.verification.broken_link.unverifiable_toast'))
        end
      end

      context 'when a link previously flagged unverifiable is replaced with a working one' do
        before do
          link.update_columns(unverifiable: true)
          allow(checker).to receive(:check_url).and_return(link_check_result(200))
        end

        it 'clears the unverifiable flag' do
          call
          expect(link.reload.unverifiable).to be false
        end
      end
    end

    context 'when a broken URL is replaced' do
      let(:checker) { instance_double(Lexicon::CheckExternalLinks, check_url: link_check_result(200)) }
      let(:entry) { create(:lex_entry, :person, status: :verifying) }
      let(:old_url) { 'https://dead.example.com/page' }
      let(:link) { create(:lex_link, item: person, description: 'אתר הזיכרון', url: old_url) }
      let(:link_params) { { url: 'https://alive.example.com/page' } }

      before do
        allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)
        allow(Lexicon::MondayReport).to receive(:call).and_return({ success: true })
        link.update_columns(http_status: 404, checked_at: 1.day.ago)
      end

      it 'reports the link, the old URL and the new URL to Monday' do
        call

        expect(Lexicon::MondayReport).to have_received(:call).with(
          hash_including(entry: entry, report_type: :fixed_broken_link, record: link, old_link: old_url)
        )
      end

      it 'reports the URL that was stored before the edit, not the new one' do
        call

        expect(Lexicon::MondayReport).to have_received(:call) do |args|
          expect(args[:old_link]).to eq(old_url)
          expect(args[:record].url).to eq('https://alive.example.com/page')
        end
      end

      it 'still saves the link and raises no toast when the report succeeds' do
        expect(call).to eq(200)
        expect(link.reload.url).to eq('https://alive.example.com/page')
        expect(response.body).not_to include('monday-report-toast-message')
      end

      context 'when the replacement URL is also broken' do
        let(:checker) { instance_double(Lexicon::CheckExternalLinks, check_url: link_check_result(404)) }

        it 'still reports the change' do
          call

          expect(Lexicon::MondayReport).to have_received(:call).with(
            hash_including(report_type: :fixed_broken_link)
          )
        end
      end

      context 'when the entry is no longer in verification' do
        let(:entry) { create(:lex_entry, :person, status: :published) }

        it 'does not report' do
          call

          expect(Lexicon::MondayReport).not_to have_received(:call)
        end
      end

      context 'when the previous URL was never flagged as broken' do
        before { link.update_columns(http_status: 200, checked_at: 1.day.ago) }

        it 'does not report' do
          call

          expect(Lexicon::MondayReport).not_to have_received(:call)
        end
      end

      context 'when the URL is unchanged' do
        let(:link_params) { { description: 'Updated description', url: old_url } }

        it 'does not report' do
          call

          expect(Lexicon::MondayReport).not_to have_received(:call)
        end
      end

      context 'when the Monday report fails' do
        before do
          allow(Lexicon::MondayReport).to receive(:call).and_return({ success: false, error: 'Invalid token' })
        end

        it 'saves the link anyway and raises a failure toast' do
          expect(call).to eq(200)
          expect(link.reload.url).to eq('https://alive.example.com/page')
          expect(response.body).to include('monday-report-toast-message')
          expect(response.body).to include(I18n.t('lexicon.verification.monday.report_error'))
        end
      end
    end

    context 'when the URL is not changed' do
      let(:link_params) { { description: 'Updated description', url: link.url } }

      it 'does not check the link' do
        allow(Lexicon::CheckExternalLinks).to receive(:new).and_call_original
        call
        expect(Lexicon::CheckExternalLinks).not_to have_received(:new)
      end
    end
  end

  describe 'DELETE /lex/links/:id' do
    subject(:call) { delete "/lex/links/#{link.id}", xhr: true }

    it 'removes record' do
      expect { call }.to change { person.links.count }.by(-1)
      expect(call).to eq(200)
    end

    it 'reloads the whole page when not in the entry-edit view' do
      call
      expect(response.body).to include('reloadPage()')
    end

    context 'when the entry is under verification' do
      before { entry.start_verification!('editor@example.com') }

      it 'drops the deleted link from the verification checklist' do
        expect { call }
          .to change { entry.reload.verification_progress.dig('checklist', 'links', 'items').keys }
          .from(match_array(links.map { |l| l.id.to_s }))
          .to(match_array(links.drop(1).map { |l| l.id.to_s }))
      end

      it 'verifies the links section once only verified links remain' do
        links.drop(1).each { |l| entry.update_checklist_item("links.items.#{l.id}", true) }
        expect { call }
          .to change { entry.reload.verification_progress.dig('checklist', 'links', 'verified') }
          .from(false).to(true)
      end
    end
  end
end
