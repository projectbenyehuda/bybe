# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification unmatched publications card', type: :request do
  before { login_as_lexicon_editor }

  let(:authority) { create(:authority, name: 'משה כהן') }
  let(:person) { create(:lex_person, authority: authority) }
  let(:entry) do
    e = create(:lex_entry, :person, lex_item: person, status: :verifying)
    e.start_verification!('editor@example.com')
    e
  end
  let(:heading) { I18n.t('lexicon.verification.sections.unmatched_publications_heading') }

  context 'when the authority has a publication not matched to any work' do
    let!(:unmatched) do
      create(:publication, authority: authority, title: 'ספר לא מותאם',
                           publisher_line: 'הוצאת דביר', pub_year: '1948')
    end
    let!(:matched) { create(:publication, authority: authority, title: 'ספר מותאם') }

    before { create(:lex_person_work, person: person, title: 'ספר מותאם', publication: matched) }

    it 'lists only the unmatched publication, with its details and a report button' do
      get "/lex/verification/#{entry.id}"

      expect(response.body).to include(heading)
      expect(response.body).to include('ספר לא מותאם')
      expect(response.body).to include('הוצאת דביר, 1948')
      expect(response.body).to include("unmatched-publication-#{unmatched.id}")
      expect(response.body).not_to include("unmatched-publication-#{matched.id}")
    end

    it 'does not render a report button on the regular work cards' do
      work = person.works.first

      get "/lex/verification/#{entry.id}"

      expect(response.body).to include("work-#{work.id}")
      # The only missing-work button on the page belongs to the unmatched publication list
      expect(response.body.scan('monday-missing-work-btn').size).to eq(1)
    end

    it 'does not count the unmatched publication in the works checklist' do
      get "/lex/verification/#{entry.id}"

      expect(entry.reload.verification_progress.dig('checklist', 'works', 'items').keys)
        .to contain_exactly(person.works.first.id.to_s)
    end
  end

  context 'when every publication of the authority is matched' do
    let!(:publication) { create(:publication, authority: authority, title: 'ספר מותאם') }

    before { create(:lex_person_work, person: person, title: 'ספר מותאם', publication: publication) }

    it 'does not render the card' do
      get "/lex/verification/#{entry.id}"

      expect(response.body).not_to include(heading)
    end
  end

  context 'when the person has no authority' do
    let(:person) { create(:lex_person, authority: nil) }

    before { create(:publication, title: 'ספר של מישהו אחר') }

    it 'does not render the card' do
      get "/lex/verification/#{entry.id}"

      expect(response.body).not_to include(heading)
    end
  end
end
