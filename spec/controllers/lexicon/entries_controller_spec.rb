# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::EntriesController, type: :controller do
  describe '#list' do
    subject(:call) { get :list }

    let!(:published_person_entry) do
      create(:lex_entry, :person, status: :published, title: 'Published Author')
    end

    let!(:draft_person_entry) do
      create(:lex_entry, :person, status: :draft, title: 'Draft Author')
    end

    let!(:deprecated_person_entry) do
      create(:lex_entry, :person, status: :deprecated, title: 'Deprecated Author')
    end

    it { is_expected.to be_successful }

    it 'assigns only published entries to @lex_entries' do
      call
      expect(assigns(:lex_entries)).to include(published_person_entry)
      expect(assigns(:lex_entries)).not_to include(draft_person_entry)
      expect(assigns(:lex_entries)).not_to include(deprecated_person_entry)
    end

    it 'orders entries by title' do
      # Create entries with different titles
      create(:lex_entry, :person, status: :published, title: 'Zebra')
      create(:lex_entry, :person, status: :published, title: 'Aardvark')

      call

      entries = assigns(:lex_entries).to_a
      expect(entries.first.title).to eq('Aardvark')
    end

    context 'when displaying the view' do
      render_views

      it 'renders the list template' do
        call
        expect(response).to render_template(:list)
      end

      it 'includes welcome title' do
        call
        expect(response.body).to include(I18n.t('lexicon.entries.list.welcome_title'))
      end

      it 'displays published entry title as a link' do
        call
        expect(response.body).to include('Published Author')
        expect(response.body).to include(lexicon_entry_path(published_person_entry))
      end

      it 'does not display draft entry' do
        call
        expect(response.body).not_to include('Draft Author')
      end

      it 'does not display deprecated entry' do
        call
        expect(response.body).not_to include('Deprecated Author')
      end
    end

    context 'with pagination' do
      before do
        # Create enough entries to require pagination
        30.times do |i|
          create(:lex_entry, :person, status: :published, title: "Person #{i}")
        end
      end

      it 'paginates the results' do
        call
        # Check that the results are paginated by checking for Kaminari methods
        expect(assigns(:lex_entries)).to respond_to(:current_page)
        expect(assigns(:lex_entries)).to respond_to(:total_pages)
      end
    end

    context 'with sorting' do
      # Use unique prefixes to ensure test isolation
      let!(:entry_z) { create(:lex_entry, :person, status: :published, title: 'ח-זלמן') }
      let!(:entry_a) { create(:lex_entry, :person, status: :published, title: 'ח-אברהם') }
      let!(:entry_m) { create(:lex_entry, :person, status: :published, title: 'ח-משה') }

      context 'when sorting alphabetically ascending (default)' do
        it 'sorts entries by title ascending' do
          call
          entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
          # Hebrew alphabet order: א ב ג ד ה ו ז ח ט י כ ל מ
          expect(entries.first.title).to eq('ח-אברהם')  # א is first
          expect(entries.last.title).to eq('ח-משה')     # מ is last
        end
      end

      context 'when sorting alphabetically descending' do
        subject(:call) { get :list, params: { sort_by: 'alphabetical_desc' } }

        it 'sorts entries by title descending' do
          call
          entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
          # Hebrew alphabet reversed
          expect(entries.first.title).to eq('ח-משה')    # מ is first when descending
          expect(entries.last.title).to eq('ח-אברהם')   # א is last when descending
        end
      end

      context 'when sorting by birth year' do
        before do
          # Update the lex_people with specific birth years
          entry_a.lex_item.update!(birthdate: '1850-01-01')
          entry_m.lex_item.update!(birthdate: '1900-01-01')
          entry_z.lex_item.update!(birthdate: '1875-01-01')
        end

        context 'when ascending' do
          subject(:call) { get :list, params: { sort_by: 'birth_year_asc' } }

          it 'sorts entries by birth year ascending' do
            call
            entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
            expect(entries[0].title).to eq('ח-אברהם') # 1850
            expect(entries[1].title).to eq('ח-זלמן')   # 1875
            expect(entries[2].title).to eq('ח-משה')    # 1900
          end
        end

        context 'when descending' do
          subject(:call) { get :list, params: { sort_by: 'birth_year_desc' } }

          it 'sorts entries by birth year descending' do
            call
            entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
            expect(entries[0].title).to eq('ח-משה')    # 1900
            expect(entries[1].title).to eq('ח-זלמן')   # 1875
            expect(entries[2].title).to eq('ח-אברהם') # 1850
          end
        end
      end

      context 'when sorting by death year' do
        before do
          # Update the lex_people with specific death years
          entry_a.lex_item.update!(deathdate: '1920-01-01')
          entry_m.lex_item.update!(deathdate: '1970-01-01')
          entry_z.lex_item.update!(deathdate: '1945-01-01')
        end

        context 'when ascending' do
          subject(:call) { get :list, params: { sort_by: 'death_year_asc' } }

          it 'sorts entries by death year ascending' do
            call
            entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
            expect(entries[0].title).to eq('ח-אברהם') # 1920
            expect(entries[1].title).to eq('ח-זלמן')   # 1945
            expect(entries[2].title).to eq('ח-משה')    # 1970
          end
        end

        context 'when descending' do
          subject(:call) { get :list, params: { sort_by: 'death_year_desc' } }

          it 'sorts entries by death year descending' do
            call
            entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
            expect(entries[0].title).to eq('ח-משה')    # 1970
            expect(entries[1].title).to eq('ח-זלמן')   # 1945
            expect(entries[2].title).to eq('ח-אברהם') # 1920
          end
        end
      end

      context 'with NULL birth/death dates' do
        let!(:entry_no_dates) do
          entry = create(:lex_entry, :person, status: :published, title: 'ח-יוסף')
          entry.lex_item.update!(birthdate: nil, deathdate: nil)
          entry
        end

        before do
          entry_a.lex_item.update!(birthdate: '1850-01-01', deathdate: '1920-01-01')
        end

        it 'handles NULL birth dates (places them last)' do
          get :list, params: { sort_by: 'birth_year_asc' }
          entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
          expect(entries.last.title).to eq('ח-יוסף') # NULL birthdate should be last
        end

        it 'handles NULL death dates (places them last)' do
          get :list, params: { sort_by: 'death_year_asc' }
          entries = assigns(:lex_entries).select { |e| e.title.start_with?('ח-') }
          expect(entries.last.title).to eq('ח-יוסף') # NULL deathdate should be last
        end
      end
    end

    context 'with filtering' do
      let!(:person_male) do
        entry = create(:lex_entry, :person, status: :published, title: 'Male Person')
        entry.lex_item.update!(gender: :male, birthdate: '1850', deathdate: '1920')
        entry
      end

      let!(:person_female) do
        entry = create(:lex_entry, :person, status: :published, title: 'Female Person')
        entry.lex_item.update!(gender: :female, birthdate: '1900', deathdate: '1980')
        entry
      end

      let!(:publication_entry) do
        create(:lex_entry, :publication, status: :published, title: 'Publication Name')
      end

      context 'when filtering by name' do
        subject(:call) { get :list, params: { name_filter: 'Female' } }

        it 'filters entries by name substring (case-insensitive)' do
          call
          expect(assigns(:lex_entries)).to include(person_female)
          expect(assigns(:lex_entries)).not_to include(person_male)
          expect(assigns(:lex_entries)).not_to include(publication_entry)
        end

        it 'builds filter pill for name' do
          call
          expect(assigns(:filters)).to include(['שם מכיל: Female', 'name_filter', :text])
        end
      end

      context 'when filtering by gender' do
        subject(:call) { get :list, params: { ckb_genders: ['female'] } }

        it 'shows only person entries with matching gender' do
          call
          expect(assigns(:lex_entries)).to include(person_female)
          expect(assigns(:lex_entries)).not_to include(person_male)
          expect(assigns(:lex_entries)).not_to include(publication_entry)
        end

        it 'sets person_filters_active flag' do
          call
          expect(assigns(:person_filters_active)).to be true
        end

        it 'builds filter pill for gender' do
          call
          expect(assigns(:filters)).to include(['נקבה', 'ckb_genders_female', :checkbox])
        end
      end

      context 'when filtering by multiple genders' do
        subject(:call) { get :list, params: { ckb_genders: %w(male female) } }

        it 'shows entries matching any selected gender' do
          call
          expect(assigns(:lex_entries)).to include(person_male, person_female)
          expect(assigns(:lex_entries)).not_to include(publication_entry)
        end
      end

      context 'when filtering by birth year range' do
        subject(:call) { get :list, params: { birth_year_from: 1875, birth_year_to: 1925 } }

        it 'filters entries within birth year range' do
          call
          expect(assigns(:lex_entries)).to include(person_female) # 1900
          expect(assigns(:lex_entries)).not_to include(person_male) # 1850
          expect(assigns(:lex_entries)).not_to include(publication_entry)
        end

        it 'builds filter pills for birth year range' do
          call
          expect(assigns(:filters)).to include(['נולד משנת: 1875', 'birth_year_from', :text])
          expect(assigns(:filters)).to include(['נולד עד שנת: 1925', 'birth_year_to', :text])
        end
      end

      context 'when filtering by birth year from only' do
        subject(:call) { get :list, params: { birth_year_from: 1875 } }

        it 'filters entries born from specified year' do
          call
          expect(assigns(:lex_entries)).to include(person_female) # 1900
          expect(assigns(:lex_entries)).not_to include(person_male) # 1850
        end
      end

      context 'when filtering by birth year to only' do
        subject(:call) { get :list, params: { birth_year_to: 1875 } }

        it 'filters entries born up to specified year' do
          call
          expect(assigns(:lex_entries)).to include(person_male) # 1850
          expect(assigns(:lex_entries)).not_to include(person_female) # 1900
        end
      end

      context 'when filtering by death year range' do
        subject(:call) { get :list, params: { death_year_from: 1950, death_year_to: 1990 } }

        it 'filters entries within death year range' do
          call
          expect(assigns(:lex_entries)).to include(person_female) # 1980
          expect(assigns(:lex_entries)).not_to include(person_male) # 1920
          expect(assigns(:lex_entries)).not_to include(publication_entry)
        end

        it 'builds filter pills for death year range' do
          call
          expect(assigns(:filters)).to include(['נפטר משנת: 1950', 'death_year_from', :text])
          expect(assigns(:filters)).to include(['נפטר עד שנת: 1990', 'death_year_to', :text])
        end
      end

      context 'when combining filters' do
        subject(:call) do
          get :list, params: {
            name_filter: 'Person',
            ckb_genders: ['female'],
            birth_year_from: 1875
          }
        end

        it 'applies all filters together' do
          call
          expect(assigns(:lex_entries)).to include(person_female)
          expect(assigns(:lex_entries)).not_to include(person_male)
          expect(assigns(:lex_entries)).not_to include(publication_entry)
        end

        it 'builds multiple filter pills' do
          call
          expect(assigns(:filters).length).to eq(3)
        end
      end

      context 'when person filters are active' do
        subject(:call) { get :list, params: { ckb_genders: ['male'] } }

        it 'excludes publication entries' do
          call
          expect(assigns(:lex_entries)).not_to include(publication_entry)
        end

        it 'only includes person entries' do
          call
          all_entries = assigns(:lex_entries).to_a
          expect(all_entries.all? { |e| e.lex_item_type == 'LexPerson' }).to be true
        end
      end

      context 'with NULL dates' do
        let!(:person_no_dates) do
          entry = create(:lex_entry, :person, status: :published, title: 'No Dates Person')
          entry.lex_item.update!(birthdate: nil, deathdate: nil)
          entry
        end

        it 'excludes entries with NULL birthdate when filtering by birth year' do
          get :list, params: { birth_year_from: 1800 }
          expect(assigns(:lex_entries)).not_to include(person_no_dates)
        end

        it 'excludes entries with NULL deathdate when filtering by death year' do
          get :list, params: { death_year_from: 1900 }
          expect(assigns(:lex_entries)).not_to include(person_no_dates)
        end
      end

      context 'with AJAX request' do
        subject(:call) { get :list, params: { ckb_genders: ['male'] }, format: :js }

        before do
          # Allow bypassing CSRF protection for JS format in tests
          allow_any_instance_of(described_class).to receive(:verify_authenticity_token)
        end

        it 'responds with JavaScript format' do
          call
          expect(response.content_type).to include('text/javascript')
        end

        it 'renders the list.js.erb template' do
          call
          expect(response).to render_template(:list)
        end
      end

      context 'with sorting and filtering together' do
        subject(:call) do
          get :list, params: {
            ckb_genders: %w(male female),
            sort_by: 'birth_year_asc'
          }
        end

        it 'applies both sorting and filtering' do
          call
          entries = assigns(:lex_entries).to_a
          expect(entries).to include(person_male, person_female)
          expect(entries.first).to eq(person_male) # 1850, earlier
          expect(entries.second).to eq(person_female) # 1900, later
        end
      end
    end
  end

  describe '#show' do
    render_views

    let(:published_entry) { create(:lex_entry, :person, status: :published) }

    context 'when user is not logged in' do
      it 'does not show edit link' do
        get :show, params: { id: published_entry.id }
        expect(response.body).not_to include(I18n.t(:edit))
      end
    end

    context 'when user is logged in but not an editor' do
      before do
        user = create(:user)
        allow_any_instance_of(described_class).to receive(:current_user).and_return(user)
      end

      it 'does not show edit link' do
        get :show, params: { id: published_entry.id }
        expect(response.body).not_to include(I18n.t(:edit))
      end
    end

    context 'when user is an editor without edit_lexicon permission' do
      before do
        editor = create(:user, editor: true)
        allow_any_instance_of(described_class).to receive(:current_user).and_return(editor)
      end

      it 'does not show edit link' do
        get :show, params: { id: published_entry.id }
        expect(response.body).not_to include(I18n.t(:edit))
      end
    end

    context 'when user is an editor with edit_lexicon permission' do
      before do
        login_as_lexicon_editor
      end

      it 'shows edit link' do
        get :show, params: { id: published_entry.id }
        expect(response.body).to include(I18n.t(:edit))
        expect(response.body).to include(edit_lexicon_entry_path(published_entry))
      end
    end
  end
end
