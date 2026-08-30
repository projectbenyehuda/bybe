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

    # We only did bibliography work for Hebrew authors, so a translated author has no Publication
    # of their own: their books are in BYP as volumes they are an involved authority of, with the
    # Publication (when there is one) filed under the Hebrew translator.
    context 'when the authority has volumes but no publications of its own' do
      let(:translator_authority) { create(:authority, name: 'Hebrew Translator') }
      let!(:translators_publication) do
        create(:publication,
               authority: translator_authority,
               title: 'The Immigrant / translated by Hebrew Translator')
      end
      let!(:volume) do
        create(:collection,
               collection_type: :volume,
               title: 'The Immigrant',
               publication: translators_publication,
               authors: [authority],
               translators: [translator_authority])
      end
      let!(:work) do
        create(:lex_person_work, person: person, title: 'The Immigrant', publication_id: nil, collection_id: nil)
      end

      it 'proposes the volume, without the translator\'s publication' do
        get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

        expect(response).to have_http_status(:success)

        # Still a proposal only -- nothing is persisted
        work.reload
        expect(work.collection_id).to be_nil

        expect(assigns(:work_matches)[work.id]).to include(
          publication_id: nil,
          collection_id: volume.id,
          collection_title: 'The Immigrant',
          similarity: 100
        )
      end
    end

    # A multi-volume work records its authorship once, on the containing volume_series, leaving the
    # member volumes with no involved_authorities of their own. Shulamit Hareven's "שונא הנסים"
    # (collection 4944, inside volume_series "צמאון: שלישיית המדבר") is the case that prompted this.
    context 'when a volume is credited to the authority only through its volume_series' do
      let!(:series_volume) do
        create(:collection, collection_type: :volume, title: 'The Miracle Hater', publication: nil, authors: [])
      end
      let!(:work) do
        create(:lex_person_work, person: person, title: 'The Miracle Hater', publication_id: nil, collection_id: nil)
      end

      before do
        create(:collection, collection_type: :volume_series, title: 'The Desert Trilogy',
                            authors: [authority], included_collections: [series_volume])
      end

      it 'proposes the volume even though it has no involved_authorities of its own' do
        expect(series_volume.involved_authorities).to be_empty

        get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

        expect(response).to have_http_status(:success)
        expect(assigns(:work_matches)[work.id]).to include(
          publication_id: nil,
          collection_id: series_volume.id,
          collection_title: 'The Miracle Hater',
          similarity: 100
        )
      end

      it 'accepts that same volume when the proposal is confirmed' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, collection_id: series_volume.id }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['success']).to be true
        expect(work.reload.collection_id).to eq(series_volume.id)
      end
    end

    context 'when a volume belongs to a publication of the same authority' do
      let!(:publication) { create(:publication, authority: authority, title: 'Own Book') }
      let!(:volume) do
        create(:collection, collection_type: :volume, title: 'Own Book', publication: publication, authors: [authority])
      end
      let!(:work) do
        create(:lex_person_work, person: person, title: 'Own Book', publication_id: nil, collection_id: nil)
      end

      it 'proposes the publication together with the volume, and proposes each only once' do
        get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

        expect(response).to have_http_status(:success)
        expect(assigns(:work_matches)[work.id]).to include(
          publication_id: publication.id,
          collection_id: volume.id,
          similarity: 100
        )
      end
    end

    # A publication and its volume are one book. Confirming either side confirms both, so the work
    # never comes out of the workbench half-matched.
    describe 'confirming a match that names only one side of a linked publication/volume pair' do
      let!(:publication) { create(:publication, authority: authority, title: 'Own Book') }
      let!(:volume) do
        create(:collection, collection_type: :volume, title: 'Own Book', publication: publication, authors: [authority])
      end
      let!(:work) do
        create(:lex_person_work, person: person, title: 'Own Book', publication_id: nil, collection_id: nil)
      end

      it 'fills in the volume when only the publication is confirmed' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, publication_id: publication.id }

        expect(response).to have_http_status(:success)
        expect(work.reload).to have_attributes(publication_id: publication.id, collection_id: volume.id)
      end

      it 'fills in the publication when only the volume is confirmed' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, collection_id: volume.id }

        expect(response).to have_http_status(:success)
        expect(work.reload).to have_attributes(publication_id: publication.id, collection_id: volume.id)
      end

      context 'when the volume is filed under another authority\'s publication' do
        let(:translators_publication) { create(:publication, authority: create(:authority), title: 'Translated') }
        let!(:translated_volume) do
          create(:collection, collection_type: :volume, title: 'Translated',
                              publication: translators_publication, authors: [authority])
        end

        it 'confirms the volume alone, since confirm would reject that publication' do
          patch "/lex/verification/#{entry.id}/confirm_work_match",
                params: { work_id: work.id, collection_id: translated_volume.id }

          expect(response).to have_http_status(:success)
          expect(work.reload).to have_attributes(publication_id: nil, collection_id: translated_volume.id)
        end
      end

      context 'when the publication has no volume' do
        let!(:volumeless_publication) { create(:publication, authority: authority, title: 'No Volume') }

        it 'confirms the publication alone' do
          patch "/lex/verification/#{entry.id}/confirm_work_match",
                params: { work_id: work.id, publication_id: volumeless_publication.id }

          expect(response).to have_http_status(:success)
          expect(work.reload).to have_attributes(publication_id: volumeless_publication.id, collection_id: nil)
        end
      end
    end

    context 'when a work is already associated with a volume but no publication' do
      let(:translators_publication) { create(:publication, title: 'Elsewhere') }
      let!(:volume) do
        create(:collection,
               collection_type: :volume, title: 'Already Matched',
               publication: translators_publication, authors: [authority])
      end
      let!(:work) do
        create(:lex_person_work,
               person: person, title: 'Already Matched', publication_id: nil, collection_id: volume.id)
      end

      it 'does not propose a match for it again' do
        get "/lex/verification/#{entry.id}/edit_section", params: { section: 'works' }

        expect(response).to have_http_status(:success)
        expect(assigns(:work_matches)[work.id]).to be_nil
      end
    end

    context 'when authority has neither publications nor volumes' do
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

    context 'when person has no associated authority' do
      let(:person_no_auth) { create(:lex_person, authority: nil) }
      let(:entry_no_auth) { create(:lex_entry, lex_item: person_no_auth, status: :verifying) }
      let!(:work_no_auth) { create(:lex_person_work, person: person_no_auth, title: 'Some Book', publication_id: nil) }

      it 'returns unprocessable with a translated error' do
        patch "/lex/verification/#{entry_no_auth.id}/confirm_work_match",
              params: { work_id: work_no_auth.id, publication_id: publication.id },
              headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq(I18n.t('lexicon.verification.messages.person_no_authority'))
      end
    end

    context 'when publication does not belong to the person\'s authority' do
      let(:other_authority) { create(:authority) }
      let!(:other_publication) { create(:publication, authority: other_authority, title: 'Foreign Book') }

      it 'returns unprocessable with a translated error' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, publication_id: other_publication.id },
              headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq(I18n.t('lexicon.verification.messages.publication_not_in_authority'))
      end
    end

    context 'when collection does not belong to the publication' do
      let(:other_publication) { create(:publication, authority: authority, title: 'Other Book') }
      let!(:other_collection) { create(:collection, publication: other_publication, title: 'Other Collection') }

      it 'returns unprocessable with a translated error' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, publication_id: publication.id, collection_id: other_collection.id },
              headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq(I18n.t('lexicon.verification.messages.collection_not_in_publication'))
      end
    end

    context 'when confirming a volume on its own' do
      let!(:volume) do
        create(:collection,
               collection_type: :volume,
               title: 'Translated Volume',
               publication: create(:publication, title: 'Filed Under The Translator'),
               authors: [authority])
      end

      it 'persists the volume with no publication' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, publication_id: '', collection_id: volume.id },
              headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['success']).to be true

        work.reload
        expect(work.publication_id).to be_nil
        expect(work.collection_id).to eq(volume.id)
      end
    end

    context 'when confirming a volume that is not one of the authority\'s' do
      let!(:foreign_volume) do
        create(:collection, collection_type: :volume, title: 'Someone Else\'s Volume', authors: [create(:authority)])
      end

      it 'returns unprocessable with a translated error' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, publication_id: '', collection_id: foreign_volume.id },
              headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq(I18n.t('lexicon.verification.messages.collection_not_in_publication'))
      end
    end

    context 'when neither a publication nor a volume is given' do
      it 'returns unprocessable with a translated error' do
        patch "/lex/verification/#{entry.id}/confirm_work_match",
              params: { work_id: work.id, publication_id: '', collection_id: '' },
              headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq(I18n.t('lexicon.verification.messages.no_match_selected'))
      end
    end
  end
end
