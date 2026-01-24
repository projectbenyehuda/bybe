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
  end
end
