# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification Auto-Matching', type: :request do
  before do
    login_as_lexicon_editor
  end

  let(:authority) { create(:authority, name: 'Test Author') }
  let(:person) { create(:lex_person, authority: authority) }
  let(:entry) { create(:lex_entry, lex_item: person, status: :verifying) }

  describe 'GET /lex/verification/:id/edit_section?section=works' do
    context 'when authority has publications' do
      let!(:publication1) do
        create(:publication,
               authority: authority,
               title: 'The Great Book')
      end

      let!(:publication2) do
        create(:publication,
               authority: authority,
               title: 'Test Author / Another Book')
      end

      let!(:publication3) do
        create(:publication,
               authority: authority,
               title: 'Different Title')
      end

      context 'with exact title matches' do
        let!(:work1) do
          create(:lex_person_work,
                 person: person,
                 title: 'The Great Book',
                 publication_id: nil)
        end

        it 'proposes match without persisting to database' do
          get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

          expect(response).to have_http_status(:success)

          # Verify work was NOT automatically updated
          work1.reload
          expect(work1.publication_id).to be_nil

          # Verify response includes proposed match data
          expect(assigns(:work_matches)).to be_present
          expect(assigns(:work_matches)[work1.id]).to include(
            publication_id: publication1.id,
            similarity: 100
          )
        end
      end

      context 'with title containing authority name' do
        let!(:work2) do
          create(:lex_person_work,
                 person: person,
                 title: 'Another Book',
                 publication_id: nil)
        end

        it 'removes authority name before matching' do
          get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

          expect(response).to have_http_status(:success)

          # Should propose match without persisting
          work2.reload
          expect(work2.publication_id).to be_nil

          # Should propose "Another Book" to "Test Author / Another Book" after normalization
          expect(assigns(:work_matches)[work2.id]).to include(
            publication_id: publication2.id,
            similarity: 100
          )
        end
      end

      context 'with fuzzy matches (70%+ similarity)' do
        let!(:work3) do
          create(:lex_person_work,
                 person: person,
                 title: 'The Grate Book', # Typo: "Grate" instead of "Great"
                 publication_id: nil)
        end

        it 'proposes match with fuzzy matching algorithm' do
          get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

          expect(response).to have_http_status(:success)

          # Should propose match without persisting
          work3.reload
          expect(work3.publication_id).to be_nil

          # Should propose match despite typo, with high similarity
          expect(assigns(:work_matches)[work3.id]).to be_present
          expect(assigns(:work_matches)[work3.id][:publication_id]).to eq(publication1.id)
          expect(assigns(:work_matches)[work3.id][:similarity]).to be >= 70
        end
      end

      context 'with collection associated to publication' do
        let!(:collection) { create(:collection, publication: publication1) }
        let!(:work4) do
          create(:lex_person_work,
                 person: person,
                 title: 'The Great Book',
                 publication_id: nil,
                 collection_id: nil)
        end

        it 'includes collection in proposed match' do
          get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

          expect(response).to have_http_status(:success)

          # Should not persist yet
          work4.reload
          expect(work4.publication_id).to be_nil
          expect(work4.collection_id).to be_nil

          # Should propose both publication and collection
          expect(assigns(:work_matches)[work4.id]).to include(
            publication_id: publication1.id,
            collection_id: collection.id
          )
        end
      end

      context 'with low similarity (below 70%)' do
        let!(:work5) do
          create(:lex_person_work,
                 person: person,
                 title: 'Completely Unrelated Title',
                 publication_id: nil)
        end

        it 'does not propose matches for works with low similarity' do
          get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

          expect(response).to have_http_status(:success)

          work5.reload
          expect(work5.publication_id).to be_nil

          # Should not propose any match for this work
          expect(assigns(:work_matches)[work5.id]).to be_nil
        end
      end

      context 'with work already having publication' do
        let!(:existing_publication) { create(:publication, authority: authority, title: 'Existing') }
        let!(:work6) do
          create(:lex_person_work,
                 person: person,
                 title: 'The Great Book',
                 publication_id: existing_publication.id)
        end

        it 'does not propose matches for works with existing publications' do
          get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

          expect(response).to have_http_status(:success)

          work6.reload
          expect(work6.publication_id).to eq(existing_publication.id)

          # Should not propose any match for work that already has a publication
          expect(assigns(:work_matches)[work6.id]).to be_nil
        end
      end

      context 'with multiple works' do
        let!(:work7) { create(:lex_person_work, person: person, title: 'The Great Book', publication_id: nil) }
        let!(:work8) { create(:lex_person_work, person: person, title: 'Another Book', publication_id: nil) }
        let!(:work9) { create(:lex_person_work, person: person, title: 'No Match', publication_id: nil) }

        it 'proposes multiple matches correctly' do
          get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

          expect(response).to have_http_status(:success)

          # Should not persist any matches yet
          work7.reload
          work8.reload
          work9.reload

          expect(work7.publication_id).to be_nil
          expect(work8.publication_id).to be_nil
          expect(work9.publication_id).to be_nil

          # Should propose matches for work7 and work8, but not work9
          expect(assigns(:work_matches)[work7.id][:publication_id]).to eq(publication1.id)
          expect(assigns(:work_matches)[work8.id][:publication_id]).to eq(publication2.id)
          expect(assigns(:work_matches)[work9.id]).to be_nil
        end
      end
    end

    context 'when person has no authority' do
      let(:person_no_auth) { create(:lex_person, authority: nil) }
      let(:entry_no_auth) { create(:lex_entry, lex_item: person_no_auth, status: :verifying) }
      let!(:work) { create(:lex_person_work, person: person_no_auth, title: 'Some Book', publication_id: nil) }

      it 'does not propose any matches' do
        get "/lex/verification/#{entry_no_auth.id}/edit_section", params: { section: 'works' }

        expect(response).to have_http_status(:success)

        work.reload
        expect(work.publication_id).to be_nil

        # Should not propose any matches (work_matches not assigned when no authority)
        expect(assigns(:work_matches)).to be_nil
      end
    end

    context 'when authority has no publications' do
      let(:authority_no_pubs) { create(:authority) }
      let(:person_no_pubs) { create(:lex_person, authority: authority_no_pubs) }
      let(:entry_no_pubs) { create(:lex_entry, lex_item: person_no_pubs, status: :verifying) }
      let!(:work) { create(:lex_person_work, person: person_no_pubs, title: 'Some Book', publication_id: nil) }

      it 'does not propose any matches' do
        get "/lex/verification/#{entry_no_pubs.id}/edit_section", params: { section: 'works' }

        expect(response).to have_http_status(:success)

        work.reload
        expect(work.publication_id).to be_nil

        # Should not propose any matches (returns empty hash when authority exists but has no pubs)
        expect(assigns(:work_matches)).to eq({})
      end
    end

    context 'when editing other sections' do
      let!(:work) { create(:lex_person_work, person: person, title: 'Some Book', publication_id: nil) }

      it 'does not perform auto-matching for non-works sections' do
        get "/lex/verification/#{entry.id}/edit_section", params: { section: 'title' }

        expect(response).to have_http_status(:success)

        work.reload
        expect(work.publication_id).to be_nil

        # work_matches should not be assigned for non-works sections
        expect(assigns(:work_matches)).to be_nil
      end
    end
  end

  describe 'PATCH /lex/verification/:id/confirm_work_match' do
    let!(:publication) { create(:publication, authority: authority, title: 'Test Book') }
    let!(:collection) { create(:collection, publication: publication, title: 'Test Collection') }
    let!(:work) do
      create(:lex_person_work,
             person: person,
             title: 'Test Book',
             publication_id: nil,
             collection_id: nil)
    end

    it 'persists the confirmed match to database' do
      patch "/lex/verification/#{entry.id}/confirm_work_match",
            params: {
              work_id: work.id,
              publication_id: publication.id,
              collection_id: collection.id
            },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)

      # Verify work was updated
      work.reload
      expect(work.publication_id).to eq(publication.id)
      expect(work.collection_id).to eq(collection.id)

      # Verify response
      json = response.parsed_body
      expect(json['success']).to be true
      expect(json['message']).to be_present
    end

    it 'handles missing work gracefully' do
      patch "/lex/verification/#{entry.id}/confirm_work_match",
            params: {
              work_id: 99_999,
              publication_id: publication.id
            },
            headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)

      json = response.parsed_body
      expect(json['success']).to be false
    end
  end
end
