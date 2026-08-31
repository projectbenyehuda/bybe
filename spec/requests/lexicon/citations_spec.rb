# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/citations' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }

  let!(:citations) { create_list(:lex_citation, 3, person: person) }

  let(:citation) { citations.first }

  describe 'GET /lexicon/people/:ID/citations' do
    subject(:call) { get "/lex/people/#{person.id}/citations" }

    it { is_expected.to eq(200) }
  end

  describe 'GET /lexicon/people/:ID/citations/new' do
    subject(:call) { get "/lex/people/#{person.id}/citations/new" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/people/:ID/citations' do
    subject(:call) { post "/lex/people/#{person.id}/citations", params: { lex_citation: citation_params }, xhr: true }

    context 'when valid params' do
      let(:citation_params) { attributes_for(:lex_citation).except(:authors, :seqno) }

      it 'creates new record' do
        expect { call }.to change { person.citations.count }.by(1)
        expect(call).to eq(200)

        citation = LexCitation.last
        expect(citation).to have_attributes(citation_params)
        expect(citation.seqno).to be_present
      end

      context 'when creating with person_work' do
        let(:work) { create(:lex_person_work, person: person, title: 'Some Work') }
        let!(:existing_citation) { create(:lex_citation, person: person, person_work: work, seqno: 2) }
        let(:citation_params) do
          attributes_for(:lex_citation).except(:authors, :seqno).merge(lex_person_work_id: work.id)
        end

        it 'adds citation to the bottom of subject_title group' do
          expect { call }.to change { person.citations.count }.by(1)
          expect(call).to eq(200)

          citation = LexCitation.last
          expect(citation.lex_person_work_id).to eq(work.id)
          expect(citation.seqno).to eq(3) # max seqno (2) + 1
        end
      end

      context 'when creating with subject string' do
        let!(:existing_citation) { create(:lex_citation, person: person, subject: 'Test Subject', seqno: 5) }
        let(:citation_params) do
          attributes_for(:lex_citation).except(:authors, :seqno, :lex_person_work_id)
                                       .merge(subject: 'Test Subject', lex_person_work_id: nil)
        end

        it 'adds citation to the bottom of subject_title group' do
          expect { call }.to change { person.citations.count }.by(1)
          expect(call).to eq(200)

          citation = LexCitation.last
          expect(citation.subject).to eq('Test Subject')
          expect(citation.seqno).to eq(6) # max seqno (5) + 1
        end
      end
    end

    context 'when invalid params' do
      let(:citation_params) { attributes_for(:lex_citation, title: '').except(:seqno) }

      it 're-renders edit form' do
        expect { call }.not_to(change { person.citations.count })
        expect(call).to eq(422)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'GET /lexicon/citations/:id/edit' do
    subject(:call) { get "/lex/citations/#{citation.id}/edit" }

    it { is_expected.to eq(200) }

    it 'renders the backup_url field' do
      call
      expect(response.body).to include('lex_citation[backup_url]')
    end
  end

  describe 'PATCH /lex/citations/:id' do
    subject(:call) { patch "/lex/citations/#{citation.id}", params: { lex_citation: citation_params }, xhr: true }

    context 'when valid params' do
      let(:citation_params) { attributes_for(:lex_citation).except(:authors, :seqno) }

      it 'updates record' do
        expect(call).to eq(200)
        expect(citation.reload).to have_attributes(citation_params)
      end
    end

    context 'when editing backup_url' do
      let(:citation_params) { { backup_url: '/files/lex/5013/00022200.pdf' } }

      it 'persists the backup_url' do
        expect(call).to eq(200)
        expect(citation.reload.backup_url).to eq('/files/lex/5013/00022200.pdf')
      end
    end

    context 'when editing notes' do
      let(:citation_params) { { notes: 'ראיון עם הסופרת לרגל צאת ספרה' } }

      it 'persists the notes' do
        expect(call).to eq(200)
        expect(citation.reload.notes).to eq('ראיון עם הסופרת לרגל צאת ספרה')
      end
    end

    context 'when invalid params' do
      let(:citation_params) { attributes_for(:lex_citation, title: '') }

      it 're-renders edit form' do
        expect(call).to eq(422)
        expect(call).to render_template(:edit)
      end
    end

    context 'when link is changed' do
      let(:checker) { instance_double(Lexicon::CheckExternalLinks) }
      let(:citation) { create(:lex_citation, person: person, link: 'https://old.example.com/') }
      let(:citation_params) { { link: 'https://new.example.com/' } }

      before do
        allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)
        citation.update_columns(link_http_status: 404)
      end

      context 'when the new link is accessible' do
        before { allow(checker).to receive(:check_url).and_return(link_check_result(200)) }

        it 'updates link_http_status synchronously' do
          call
          expect(citation.reload.link_http_status).to eq(200)
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
          expect(citation.reload.link_http_status).to eq(404)
        end

        it 'includes an error toast in the response' do
          call
          expect(response.body).to include('showToast')
          expect(response.body).to include('error')
        end
      end

      context 'when the link is unreachable (host defunct)' do
        before { allow(checker).to receive(:check_url).and_return(link_check_result(nil)) }

        it 'stores nil status but records the check time and flags it broken' do
          call
          citation.reload
          expect(citation.link_http_status).to be_nil
          expect(citation.link_checked_at).to be_present
          expect(citation).to be_link_broken
        end

        it 'includes an error toast in the response' do
          call
          expect(response.body).to include('showToast')
          expect(response.body).to include('error')
        end
      end
    end

    context 'when a broken link is replaced' do
      let(:checker) { instance_double(Lexicon::CheckExternalLinks, check_url: link_check_result(200)) }
      let(:entry) { create(:lex_entry, :person, status: :verifying) }
      let(:person) { entry.lex_item }
      let(:old_link) { 'https://dead.example.com/page' }
      let(:citation) do
        create(:lex_citation, person: person, title: 'על מוישה זוכמיר', link: old_link,
                              link_http_status: 404, link_checked_at: 1.day.ago)
      end
      let(:citation_params) { { link: 'https://alive.example.com/page' } }

      before do
        allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)
        allow(Lexicon::MondayReport).to receive(:call).and_return({ success: true })
      end

      it 'reports the citation, the old link and the new link to Monday' do
        call

        expect(Lexicon::MondayReport).to have_received(:call).with(
          hash_including(entry: entry, report_type: :fixed_broken_link, record: citation, old_link: old_link)
        )
      end

      it 'reports the link that was stored before the edit, not the new one' do
        call

        expect(Lexicon::MondayReport).to have_received(:call) do |args|
          expect(args[:old_link]).to eq(old_link)
          expect(args[:record].link).to eq('https://alive.example.com/page')
        end
      end

      it 'still saves the citation and raises no toast when the report succeeds' do
        expect(call).to eq(200)
        expect(citation.reload.link).to eq('https://alive.example.com/page')
        expect(response.body).not_to include('monday-report-toast-message')
      end

      context 'when the replacement link is also broken' do
        let(:checker) { instance_double(Lexicon::CheckExternalLinks, check_url: link_check_result(404)) }

        it 'still reports the change' do
          call

          expect(Lexicon::MondayReport).to have_received(:call).with(
            hash_including(report_type: :fixed_broken_link)
          )
        end
      end

      context 'when the broken link is cleared rather than replaced' do
        let(:citation_params) { { link: '' } }

        it 'reports the removal' do
          call

          expect(Lexicon::MondayReport).to have_received(:call).with(
            hash_including(report_type: :fixed_broken_link, old_link: old_link)
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

      context 'when the previous link was never flagged as broken' do
        let(:citation) do
          create(:lex_citation, person: person, link: old_link, link_http_status: 200, link_checked_at: 1.day.ago)
        end

        it 'does not report' do
          call

          expect(Lexicon::MondayReport).not_to have_received(:call)
        end
      end

      context 'when the link is not changed' do
        let(:citation_params) { { title: 'New Title', link: old_link } }

        it 'does not report' do
          call

          expect(Lexicon::MondayReport).not_to have_received(:call)
        end
      end

      context 'when the Monday report fails' do
        before do
          allow(Lexicon::MondayReport).to receive(:call).and_return({ success: false, error: 'Invalid token' })
        end

        it 'saves the citation anyway and raises a failure toast' do
          expect(call).to eq(200)
          expect(citation.reload.link).to eq('https://alive.example.com/page')
          expect(response.body).to include('monday-report-toast-message')
          expect(response.body).to include(I18n.t('lexicon.verification.monday.report_error'))
        end
      end
    end

    context 'when link is cleared' do
      let(:citation) { create(:lex_citation, person: person, link: 'https://old.example.com/', link_http_status: 404) }
      let(:citation_params) { { link: '' } }

      it 'resets link_http_status and link_checked_at to nil without making a network request' do
        allow(Lexicon::CheckExternalLinks).to receive(:new).and_call_original
        call
        expect(Lexicon::CheckExternalLinks).not_to have_received(:new)
        citation.reload
        expect(citation.link_http_status).to be_nil
        expect(citation.link_checked_at).to be_nil
      end
    end

    context 'when link is not changed' do
      let(:existing_link) { 'https://unchanged.example.com/' }
      let(:citation) { create(:lex_citation, person: person, link: existing_link) }
      let(:citation_params) { { title: 'New Title', link: existing_link } }

      it 'does not check the link' do
        allow(Lexicon::CheckExternalLinks).to receive(:new).and_call_original
        call
        expect(Lexicon::CheckExternalLinks).not_to have_received(:new)
      end
    end

    context 'when subject_title is changed' do
      let!(:work1) { create(:lex_person_work, person: person, title: 'Work A') }
      let!(:work2) { create(:lex_person_work, person: person, title: 'Work B') }

      let!(:citation1) { create(:lex_citation, person: person, person_work: work1, seqno: 1) }
      let!(:citation2) { create(:lex_citation, person: person, person_work: work1, seqno: 2) }
      let!(:citation3) { create(:lex_citation, person: person, person_work: work2, seqno: 3) }

      let(:citation) { citation1 }

      context 'when changing person_work to an existing work' do
        let(:citation_params) { { lex_person_work_id: work2.id } }

        it 'adds citation to the bottom of the new subject_title list' do
          expect(call).to eq(200)
          expect(citation.reload).to have_attributes(lex_person_work_id: work2.id, seqno: 4)
        end
      end

      context 'when changing to a new subject string' do
        let(:citation_params) { { subject: 'New Subject', lex_person_work_id: nil } }

        it 'sets seqno to 1' do
          expect(call).to eq(200)
          citation.reload
          expect(citation.subject).to eq('New Subject')
          expect(citation.lex_person_work_id).to be_nil
          expect(citation.seqno).to eq(1)
        end
      end
    end
  end

  describe 'DELETE /lex/citations/:id' do
    subject(:call) { delete "/lex/citations/#{citation.id}", xhr: true }

    it 'removes record' do
      expect { call }.to change { person.citations.count }.by(-1)
      expect(call).to eq(200)
    end

    it 'reloads the whole page when not in the entry-edit view' do
      call
      expect(response.body).to include('reloadPage()')
    end

    context 'when the entry is under verification' do
      let(:entry) { person.entry }

      before { entry.start_verification!('editor@example.com') }

      it 'drops the deleted citation from the verification checklist' do
        expect { call }
          .to change { entry.reload.verification_progress.dig('checklist', 'citations', 'items').keys }
          .from(match_array(citations.map { |c| c.id.to_s }))
          .to(match_array(citations.drop(1).map { |c| c.id.to_s }))
      end

      it 'verifies the citations section once only verified citations remain' do
        citations.drop(1).each { |c| entry.update_checklist_item("citations.items.#{c.id}", true) }
        expect { call }
          .to change { entry.reload.verification_progress.dig('checklist', 'citations', 'verified') }
          .from(false).to(true)
      end
    end
  end

  describe 'GET /lex/citations/:id/text_links' do
    it 'returns 200' do
      expect(get("/lex/citations/#{citation.id}/text_links", xhr: true)).to eq(200)
    end
  end

  describe 'POST /lex/citations/:id/add_text_link' do
    subject(:call) do
      post "/lex/citations/#{citation.id}/add_text_link",
           params: { text: 'שדות ומזוודות', entry_id: target_entry.id },
           xhr: true
    end

    let!(:target_entry) { create(:lex_file, :publication, title: 'שדות ומזוודות').lex_entry }

    it 'adds the text link and returns 200' do
      expect(call).to eq(200)
      expect(citation.reload.text_links).to eq([{ 'text' => 'שדות ומזוודות', 'entry_id' => target_entry.id }])
    end

    it 'does not duplicate an existing link with the same text' do
      citation.update!(text_links: [{ 'text' => 'שדות ומזוודות', 'entry_id' => target_entry.id }])
      expect { call }.not_to(change { citation.reload.text_links.size })
    end

    context 'when a url is given instead of an entry' do
      subject(:call) do
        post "/lex/citations/#{citation.id}/add_text_link",
             params: { text: 'שדות ומזוודות', url: 'http://example.com/page' },
             xhr: true
      end

      it 'adds a url link pair' do
        expect(call).to eq(200)
        expect(citation.reload.text_links).to eq([{ 'text' => 'שדות ומזוודות', 'url' => 'http://example.com/page' }])
      end
    end

    context 'when text is blank' do
      subject(:call) do
        post "/lex/citations/#{citation.id}/add_text_link",
             params: { text: '', entry_id: target_entry.id },
             xhr: true
      end

      it 'returns 422' do
        expect(call).to eq(422)
      end
    end
  end

  describe 'DELETE /lex/citations/:id/remove_text_link' do
    subject(:call) { delete "/lex/citations/#{citation.id}/remove_text_link", params: { index: 0 }, xhr: true }

    before do
      citation.update!(text_links: [{ 'text' => 'שדות ומזוודות', 'entry_id' => 1 },
                                    { 'text' => 'לספר את הקיבוץ', 'url' => 'http://example.com' }])
    end

    it 'removes the link at the given index and returns 200' do
      expect(call).to eq(200)
      expect(citation.reload.text_links).to eq([{ 'text' => 'לספר את הקיבוץ', 'url' => 'http://example.com' }])
    end

    it 'returns 422 and removes nothing when the index is not an integer' do
      delete "/lex/citations/#{citation.id}/remove_text_link", params: { index: 'abc' }, xhr: true
      expect(response).to have_http_status(:unprocessable_content)
      expect(citation.reload.text_links.size).to eq(2)
    end
  end

  describe 'POST /lex/citations/:id/reorder' do
    subject(:call) do
      post "/lex/citations/#{citation_to_move.id}/reorder",
           params: { new_index: new_index, old_index: old_index, group_token: group_token }.merge(extra_params),
           xhr: true
    end

    let(:work) { create(:lex_person_work, person: person, title: 'Test Work') }
    let(:group_token) { work.title }
    let(:extra_params) { {} }

    let!(:citation_1) { create(:lex_citation, person: person, person_work: work, seqno: 2) }
    let!(:citation_2) { create(:lex_citation, person: person, person_work: work, seqno: 3) }
    let!(:citation_3) { create(:lex_citation, person: person, person_work: work, seqno: 5) }
    let!(:citation_4) { create(:lex_citation, person: person, person_work: work, seqno: 6) }
    let!(:other_work) { create(:lex_person_work, person: person, title: 'Other Work') }
    let!(:other_citation) { create(:lex_citation, person: person, person_work: other_work, seqno: 1) }

    let(:reordered_citations) { person.reload.citations.where(lex_person_work_id: work.id).order(:seqno) }

    context 'when we move item forward' do
      let(:citation_to_move) { citation_1 }
      let(:old_index) { 0 }
      let(:new_index) { 3 }

      it 'reorders citations and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_citations.map(&:id)).to eq([citation_2.id, citation_3.id, citation_4.id, citation_1.id])
        expect(reordered_citations.map(&:seqno)).to eq((1..4).to_a)
      end
    end

    context 'when we move item backward' do
      let(:citation_to_move) { citation_3 }
      let(:old_index) { 2 }
      let(:new_index) { 1 }

      it 'reorders citations and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_citations.map(&:id)).to eq([citation_1.id, citation_3.id, citation_2.id, citation_4.id])
        expect(reordered_citations.map(&:seqno)).to eq((1..4).to_a)
      end
    end

    context 'when old_index does not match' do
      let(:old_index) { 1 }
      let(:new_index) { 2 }
      let(:citation_to_move) { citation_3 }

      it 'fails with bad request' do
        expect(call).to eq(400)
        expect(response.body).to eq('old_index mismatch, actual: 2, got: 1')
      end
    end

    context 'when group_token does not match' do
      let(:citation_to_move) { other_citation }
      let(:old_index) { 0 }
      let(:new_index) { 1 }

      it 'fails with bad request' do
        expect(call).to eq(400)
        expect(response.body).to eq("group_token mismatch, actual: '#{other_work.title}', got: '#{work.title}'")
      end
    end

    context 'when using subject string instead of person_work' do
      let(:group_token) { 'Subject String' }

      let!(:citation_1) { create(:lex_citation, person: person, subject: group_token, seqno: 1) }
      let!(:citation_2) { create(:lex_citation, person: person, subject: group_token, seqno: 2) }
      let!(:citation_3) { create(:lex_citation, person: person, subject: group_token, seqno: 3) }

      let(:citation_to_move) { citation_1 }
      let(:old_index) { 0 }
      let(:new_index) { 2 }

      it 'reorders citations correctly' do
        expect(call).to eq(200)

        reordered = person.reload.citations.select { |c| c.subject == group_token }.sort_by(&:seqno)
        expect(reordered.map(&:id)).to eq([citation_2.id, citation_3.id, citation_1.id])
        expect(reordered.map(&:seqno)).to eq((1..3).to_a)
      end
    end

    # Dragging a citation from one general bucket into another (see LexCitationGroup).
    context 'when moving a citation to another general bucket' do
      let(:group) { create(:lex_citation_group, person: person, title: 'ספרים') }
      let!(:general_1) { create(:lex_citation, person: person, seqno: 1) }
      let!(:general_2) { create(:lex_citation, person: person, seqno: 2) }
      let!(:grouped) { create_list(:lex_citation, 2, person: person, citation_group: group) }

      let(:citation_to_move) { general_2 }
      let(:group_token) { '' }
      let(:extra_params) { { to_group_token: "heading:#{group.id}" } }
      let(:old_index) { 1 }
      let(:new_index) { 1 }

      it 'files it under the target sub-heading at the requested position' do
        expect(call).to eq(200)

        expect(general_2.reload.citation_group).to eq(group)
        expect(group.citations.order(:seqno).map(&:id)).to eq([grouped.first.id, general_2.id, grouped.last.id])
        expect(group.citations.order(:seqno).map(&:seqno)).to eq((1..3).to_a)
      end

      it 'renumbers the bucket the citation left, leaving no gap where it was' do
        call
        remaining = person.reload.citations_by_group_token(nil).sort_by(&:seqno)
        expect(remaining).not_to include(general_2)
        expect(remaining.map(&:seqno)).to eq((1..remaining.size).to_a)
      end

      it 'moves a citation back out of a sub-heading into the ungrouped general list' do
        post "/lex/citations/#{grouped.first.id}/reorder",
             params: { new_index: 0, old_index: 0, group_token: "heading:#{group.id}", to_group_token: '' },
             xhr: true

        expect(response).to have_http_status(:ok)
        expect(grouped.first.reload.citation_group).to be_nil
        general = person.reload.citations_by_group_token(nil).sort_by(&:seqno)
        expect(general.first).to eq(grouped.first)
        expect(general.map(&:seqno)).to eq((1..general.size).to_a)
      end

      # A drag can only rearrange the general buckets; what a citation is about is set on its form.
      it 'refuses to move a citation under a work' do
        post "/lex/citations/#{general_2.id}/reorder",
             params: { new_index: 0, old_index: 1, group_token: '', to_group_token: work.title },
             xhr: true

        expect(response).to have_http_status(:bad_request)
        expect(general_2.reload.person_work).to be_nil
      end

      # Dragging out of a work's list would leave the citation both about a work and under a
      # general sub-heading, which LexCitation forbids -- and renumber saves without validating.
      it 'refuses to move a citation out of a work\'s list' do
        about_work = create(:lex_citation, person: person, person_work: work, seqno: 1)
        post "/lex/citations/#{about_work.id}/reorder",
             params: { new_index: 0, old_index: 0, group_token: work.title,
                       to_group_token: "heading:#{group.id}" },
             xhr: true

        expect(response).to have_http_status(:bad_request)
        expect(about_work.reload.citation_group).to be_nil
        expect(about_work.person_work).to eq(work)
      end

      it 'refuses a sub-heading belonging to another person' do
        other_group = create(:lex_citation_group, person: create(:lex_entry, :person).lex_item)
        post "/lex/citations/#{general_2.id}/reorder",
             params: { new_index: 0, old_index: 1, group_token: '',
                       to_group_token: "heading:#{other_group.id}" },
             xhr: true

        expect(response).to have_http_status(:bad_request)
        expect(general_2.reload.citation_group).to be_nil
      end
    end
  end
end
