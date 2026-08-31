# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/entries' do
  describe '#index' do
    subject { get '/lex/entries', params: params }

    before do
      login_as_lexicon_editor
      create_list(:lex_entry, 2, :person)
      create_list(:lex_entry, 2, :publication)
    end

    let(:params) { {} }

    it { is_expected.to eq(200) }

    context 'when filtering by status' do
      before do
        create(:lex_entry, :person, status: :draft, title: 'Draft Entry')
        create(:lex_entry, :person, status: :published, title: 'Published Entry')
        create(:lex_entry, :person, status: :verified, title: 'Verified Entry')
      end

      let(:params) { { status: 'draft' } }

      it 'returns only entries with the specified status' do
        expect(subject).to eq(200)
        get '/lex/entries', params: params
        expect(assigns(:lex_entries).map(&:status)).to all(eq('draft'))
        expect(assigns(:lex_entries).pluck(:title)).to include('Draft Entry')
        expect(assigns(:lex_entries).pluck(:title)).not_to include('Published Entry', 'Verified Entry')
      end
    end

    context 'when filtering by title substring' do
      before do
        create(:lex_entry, :person, title: 'Albert Einstein')
        create(:lex_entry, :person, title: 'Marie Curie')
        create(:lex_entry, :person, title: 'Isaac Newton')
      end

      let(:params) { { title: 'ein' } }

      it 'returns only entries with titles matching the substring' do
        expect(subject).to eq(200)
        get '/lex/entries', params: params
        expect(assigns(:lex_entries).pluck(:title)).to include('Albert Einstein')
        expect(assigns(:lex_entries).pluck(:title)).not_to include('Marie Curie', 'Isaac Newton')
      end
    end

    context 'when filtering by both status and title' do
      before do
        create(:lex_entry, :person, status: :draft, title: 'Test Draft Entry')
        create(:lex_entry, :person, status: :published, title: 'Test Published Entry')
        create(:lex_entry, :person, status: :draft, title: 'Another Draft Entry')
      end

      let(:params) { { status: 'draft', title: 'Test' } }

      it 'returns entries matching both filters' do
        expect(subject).to eq(200)
        get '/lex/entries', params: params
        expect(assigns(:lex_entries).count).to eq(1)
        expect(assigns(:lex_entries).first.title).to eq('Test Draft Entry')
      end
    end
  end

  describe '#edit' do
    subject { get "/lex/entries/#{entry.id}/edit" }

    before do
      login_as_lexicon_editor
    end

    context 'when entry is a Person' do
      let(:entry) { create(:lex_entry, :person) }
      let(:authority) { create(:authority) }

      it { is_expected.to eq(200) }
    end

    context 'when entry is a Publication' do
      let(:entry) { create(:lex_entry, :publication) }

      it { is_expected.to eq(200) }
    end
  end

  describe '#show' do
    subject(:call) { get "/lex/entries/#{entry.id}" }

    context 'when entry is not migrated yet' do
      let(:entry) { create(:lex_entry, :person, status: :raw) }
      let!(:lex_file) { create(:lex_file, lex_entry: entry, fname: '00021.php') }

      it 'redirects to old_file' do
        expect(call).to redirect_to('https://benyehuda.org/lexicon/00021.php')
      end
    end

    context 'when entry is migrated but not published' do
      let(:entry) { create(:lex_entry, :person, status: :verifying) }
      let!(:lex_file) { create(:lex_file, lex_entry: entry, fname: '00022.php') }

      context 'when user is not logged in' do
        it 'redirects to old lexicon' do
          expect(call).to redirect_to('https://benyehuda.org/lexicon/00022.php')
        end
      end

      context 'when user is a lexicon editor' do
        before do
          login_as_lexicon_editor
        end

        it 'renders page' do
          expect(call).to eq(200)
        end
      end
    end

    context 'when entry is a Person' do
      let(:entry) { create(:lex_entry, :person, status: :published) }

      it { is_expected.to eq(200) }

      context 'when entry has authority' do
        before do
          entry.lex_item.update!(authority_id: authority.id)
        end

        let(:authority) { create(:authority) }

        it { is_expected.to eq(200) }
      end

      context 'when a work is associated with a collection' do
        let(:collection) { create(:collection, title: 'כרך מקוון') }
        let!(:work) do
          create(:lex_person_work, person: entry.lex_item, title: 'ספר הזכרונות', collection: collection)
        end

        it 'links the work title to the collection' do
          expect(call).to eq(200)
          expect(response.body).to include(%(<a href="#{collection_path(collection)}">ספר הזכרונות</a>))
        end
      end
    end

    context 'when entry is a Publication' do
      let(:entry) { create(:lex_entry, :publication, status: :published) }

      it { is_expected.to eq(200) }
    end

    describe 'empty sections' do
      context 'when a Person entry has no works, citations, links or identifiers' do
        let(:entry) { create(:lex_entry, :person, status: :published) }

        it 'omits those cards' do
          expect(call).to eq(200)
          expect(response.body).not_to include('id="lexicon-works"')
          expect(response.body).not_to include('id="lexicon-about"')
          expect(response.body).not_to include('id="lexicon-links"')
          expect(response.body).not_to include('id="lexicon-authority-control"')
        end

        it 'omits their navbar lines, keeping only the biography' do
          expect(call).to eq(200)
          expect(response.body).to include('data-scroll-target="#lexicon-biography"')
          expect(response.body).not_to include('data-scroll-target="#lexicon-works"')
          expect(response.body).not_to include('data-scroll-target="#lexicon-about"')
          expect(response.body).not_to include('data-scroll-target="#lexicon-links"')
        end
      end

      context 'when a Person entry has works, citations and links' do
        let(:entry) { create(:lex_entry, :person, status: :published) }

        before do
          create(:lex_person_work, person: entry.lex_item)
          create(:lex_citation, person: entry.lex_item)
          create(:lex_link, item: entry.lex_item)
        end

        it 'shows those cards and their navbar lines' do
          expect(call).to eq(200)
          expect(response.body).to include('id="lexicon-works"')
          expect(response.body).to include('id="lexicon-about"')
          expect(response.body).to include('id="lexicon-links"')
          expect(response.body).to include('data-scroll-target="#lexicon-works"')
          expect(response.body).to include('data-scroll-target="#lexicon-about"')
          expect(response.body).to include('data-scroll-target="#lexicon-links"')
        end

        # The general citations come first, ungrouped ones then each sub-heading, and only then the
        # citations about a work. See LexCitationGroup and LexiconHelper#grouped_and_ordered_citations.
        it 'headlines a general sub-heading verbatim, above the work headings' do
          person = entry.lex_item
          group = create(:lex_citation_group, person: person, title: 'ספרים')
          create(:lex_citation, person: person, citation_group: group, title: 'מונוגרפיה על היוצר')
          work = create(:lex_person_work, person: person, title: 'ספר הזכרונות')
          create(:lex_citation, person: person, person_work: work, title: 'מאמר על הספר')

          call
          headings = rendered.all('#lexicon-about h4').map(&:text)
          expect(headings).to eq(['ספרים', I18n.t('lexicon.citations.header.subject_line', subject: 'ספר הזכרונות')])
        end
      end

      context 'when a Person entry has no biography' do
        let(:entry) { create(:lex_entry, :person, status: :published, lex_item: create(:lex_person, bio: nil)) }

        let(:active_works_link) { '<a aria-selected="true" class="nav-link active" href="#" id="works_button">' }

        before { create(:lex_person_work, person: entry.lex_item) }

        it 'omits the biography and starts the navbar on the first surviving section' do
          expect(call).to eq(200)
          expect(response.body).not_to include('id="lexicon-biography"')
          expect(response.body).not_to include('data-scroll-target="#lexicon-biography"')
          expect(response.body).to include(active_works_link)
        end
      end

      context 'when a Publication entry has no table of contents' do
        let(:entry) do
          create(:lex_entry, :publication, status: :published, lex_item: create(:lex_publication, toc: nil))
        end

        it 'omits the toc card and its navbar line' do
          expect(call).to eq(200)
          expect(response.body).to include('id="lexicon-description"')
          expect(response.body).not_to include('id="lexicon-toc"')
          expect(response.body).not_to include('data-scroll-target="#lexicon-toc"')
        end
      end
    end

    describe 'last updated line' do
      context 'when the legacy PHP file carried a manual update date' do
        let(:entry) { create(:lex_entry, :person, status: :published, date_of_manual_update: '12 ביולי 2023') }

        it 'shows the ingested date' do
          expect(call).to eq(200)
          expect(response.body).to include('lexicon-last-updated')
          expect(response.body).to include('12 ביולי 2023')
        end
      end

      context 'when the legacy PHP file carried no manual update date' do
        let(:entry) { create(:lex_entry, :person, status: :published, date_of_manual_update: nil) }

        it 'omits the line rather than presenting the migration date as a manual update' do
          expect(call).to eq(200)
          expect(response.body).not_to include('lexicon-last-updated')
        end
      end
    end
  end

  describe 'DELETE /destroy' do
    subject(:call) { delete "/lex/entries/#{entry.id}" }

    before do
      login_as_lexicon_editor
    end

    context 'when entry is a Person' do
      let!(:entry) { create(:lex_entry, :person) }

      it 'destroys the requested LexEntry and LexPerson' do
        expect { call }.to change(LexPerson, :count).by(-1).and change(LexEntry, :count).by(-1)
        expect(call).to redirect_to lexicon_entries_path
        expect(flash.alert).to eq(I18n.t('lexicon.entries.destroy.success'))
      end
    end

    context 'when entry is a Publication' do
      let!(:entry) { create(:lex_entry, :publication) }

      it 'destroys the requested LexEntry and LexPublication' do
        expect { call }.to change(LexPublication, :count).by(-1).and change(LexEntry, :count).by(-1)
        expect(call).to redirect_to lexicon_entries_path
        expect(flash.alert).to eq(I18n.t('lexicon.entries.destroy.success'))
      end
    end
  end
end
