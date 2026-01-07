# frozen_string_literal: true

require 'rails_helper'

describe IngestiblesController do
  include_context 'when editor logged in', :edit_catalog

  describe '#index' do
    subject { get :index }

    before do
      create_list(:ingestible, 5)
    end

    it { is_expected.to be_successful }
  end

  describe '#new' do
    subject { get :new }

    it { is_expected.to be_successful }
  end

  describe '#create' do
    subject(:call) { post :create, params: { ingestible: ingestible_params } }

    context 'with valid params' do
      let(:ingestible_params) do
        attributes_for(:ingestible)
      end

      it 'creates new record and redirects to edit page' do
        expect { call }.to change(Ingestible, :count).by(1)
        ingestible = Ingestible.order(id: :desc).first
        expect(call).to redirect_to edit_ingestible_path(ingestible)
        expect(flash.notice).to eq I18n.t('ingestibles.create.success')
      end
    end

    context 'with invalid params' do
      let(:ingestible_params) do
        attributes_for(:ingestible, title: nil)
      end

      it 're-renders new page' do
        expect { call }.to not_change(Ingestible, :count)
        expect(call).to render_template(:new)
      end
    end

    context 'with duplicate volume params' do
      let(:authority) { create(:authority) }
      let(:publication) { create(:publication, authority: authority) }
      let!(:existing_volume) do
        # Create an existing volume for this publication with this authority
        collection = create(:collection, collection_type: 'volume', publication: publication, title: 'Existing Volume')
        collection.involved_authorities.create!(authority: authority, role: :author)
        collection
      end
      let(:ingestible_params) do
        # User tries to create another volume for the same publication
        # update_authorities_and_metadata_from_volume will populate collection_authorities
        # with the publication's authority (author role by default)
        attributes_for(:ingestible,
                       no_volume: false,
                       prospective_volume_id: "P#{publication.id}",
                       prospective_volume_title: nil) # Will use publication title
      end

      it 'does not crash and re-renders new page with validation error' do
        expect { call }.to not_change(Ingestible, :count)
        expect(call).to render_template(:new)
        expect(assigns(:ingestible).errors[:prospective_volume_id]).to include(I18n.t('ingestible.errors.duplicate_volume_for_publication'))
      end
    end
  end

  describe 'Member Actions' do
    let!(:ingestible) { create(:ingestible, locked_by_user: locked_by_user, locked_at: locked_at) }
    let(:locked_by_user) { nil }
    let(:locked_at) { nil }

    shared_context 'redirects to show page if record cannot be locked' do
    end

    describe '#show' do
      subject { get :show, params: { id: ingestible.id } }

      it { is_expected.to be_successful }
    end

    describe '#edit' do
      subject(:call) { get :edit, params: { id: ingestible.id } }

      # it_behaves_like 'redirects to show page if record cannot be locked'

      it { is_expected.to be_successful }

      context 'when ingestible has works with footnotes' do
        let(:ingestible) { create(:ingestible, :with_footnotes) }

        before do
          ingestible.update_parsing
          call
        end

        it 'generates HTML with unique footnote anchors for each section' do
          html = controller.instance_variable_get(:@html)
          expect(html).to be_present
          # Check that footnote anchors from different sections have different nonces
          expect(html).to include('fn:md_0_1') # First section's footnote
          expect(html).to include('fn:md_1_1') # Second section's footnote
          # Ensure the anchors are not duplicated without nonces
          expect(html.scan('id="fn:1"').count).to eq(0)
        end
      end
    end

    describe '#update' do
      subject(:call) { patch :update, params: { id: ingestible.id, ingestible: ingestible_params } }

      let(:ingestible_params) { attributes_for(:ingestible).except(:markdown, :toc_buffer) }

      # it_behaves_like 'redirects to show page if record cannot be locked'

      context 'when valid params' do
        it 'updates record and re-renders edit page' do
          expect(call).to redirect_to edit_ingestible_path(ingestible)
          ingestible.reload
          expect(ingestible).to have_attributes(ingestible_params)
          expect(flash.notice).to eq I18n.t('ingestibles.update.success')
        end
      end

      context 'when invalid params' do
        let(:ingestible_params) { attributes_for(:ingestible, title: nil) }

        it 're-renders edit form' do
          expect(call).to have_http_status(:unprocessable_content)
          expect(call).to render_template(:edit)
        end
      end
    end

    describe '#update_markdown' do
      subject(:call) { patch :update_markdown, params: { id: ingestible.id, ingestible: { markdown: new_markdown } } }

      let(:new_markdown) { Faker::Lorem.paragraph }

      # it_behaves_like 'redirects to show page if record cannot be locked'

      it 'updates record and re-renders edit page' do
        expect(call).to redirect_to "#{edit_ingestible_path(ingestible)}?tab=full_markdown"
        ingestible.reload
        expect(ingestible.markdown).to eq new_markdown
        expect(flash.notice).to eq I18n.t(:updated_successfully)
      end
    end

    describe '#destroy' do
      subject(:call) { delete :destroy, params: { id: ingestible.id } }

      # it_behaves_like 'redirects to show page if record cannot be locked'

      it 'removes record and redirects to index page' do
        expect { call }.to change(Ingestible, :count).by(-1)
        expect(call).to redirect_to ingestibles_path
        expect(flash.notice).to eq I18n.t('ingestibles.destroy.success')
      end
    end

    describe '#update_toc' do
      let(:authority) { create(:authority) }
      let(:toc_buffer) do
        ' yes || Test Work || || pros || he || public_domain'
      end
      let(:ingestible) do
        create(:ingestible,
               toc_buffer: toc_buffer,
               default_authorities: [{ seqno: 1, authority_id: authority.id, authority_name: authority.name,
                                       role: 'translator' }].to_json)
      end

      context 'when clearing default authorities for a specific work' do
        subject(:call) do
          patch :update_toc, params: { id: ingestible.id, title: 'Test Work', clear_defaults: true }, xhr: true,
                             format: :js
        end

        # it_behaves_like 'redirects to show page if record cannot be locked'

        it 'sets authorities to empty array for that work' do
          call
          ingestible.reload
          decoded_toc = ingestible.decode_toc
          expect(decoded_toc.first[2]).to eq '[]'
        end

        it 'allows the work to have no authorities during ingestion' do
          call
          ingestible.reload
          toc_line = ingestible.decode_toc.first
          auths = controller.send(:merge_authorities_per_role, toc_line[2], ingestible.default_authorities)
          expect(auths).to eq([])
        end
      end

      context 'when not clearing default authorities' do
        it 'uses default authorities during ingestion' do
          ingestible.reload
          toc_line = ingestible.decode_toc.first
          auths = controller.send(:merge_authorities_per_role, toc_line[2], ingestible.default_authorities)
          expect(auths.length).to eq(1)
          expect(auths.first['authority_id']).to eq(authority.id)
          expect(auths.first['role']).to eq('translator')
        end
      end

      context 'when adding specific author with default translator' do
        let(:author) { create(:authority) }

        before do
          # Add an author to the work
          cur_toc = ingestible.decode_toc
          cur_toc.first[2] =
            [{ seqno: 1, authority_id: author.id, authority_name: author.name, role: 'author' }].to_json
          ingestible.update_columns(toc_buffer: ingestible.encode_toc(cur_toc))
        end

        it 'merges per role: uses specific author and default translator' do
          ingestible.reload
          toc_line = ingestible.decode_toc.first
          auths = controller.send(:merge_authorities_per_role, toc_line[2], ingestible.default_authorities)

          expect(auths.length).to eq(2)
          author_auth = auths.find { |a| a['role'] == 'author' }
          translator_auth = auths.find { |a| a['role'] == 'translator' }

          expect(author_auth['authority_id']).to eq(author.id)
          expect(translator_auth['authority_id']).to eq(authority.id)
        end
      end

      context 'when overriding default translator with specific translator' do
        let(:different_translator) { create(:authority) }

        before do
          # Add a different translator to the work
          cur_toc = ingestible.decode_toc
          cur_toc.first[2] =
            [{ seqno: 1, authority_id: different_translator.id, authority_name: different_translator.name,
               role: 'translator' }].to_json
          ingestible.update_columns(toc_buffer: ingestible.encode_toc(cur_toc))
        end

        it 'uses specific translator instead of default' do
          ingestible.reload
          toc_line = ingestible.decode_toc.first
          auths = controller.send(:merge_authorities_per_role, toc_line[2], ingestible.default_authorities)

          expect(auths.length).to eq(1)
          expect(auths.first['authority_id']).to eq(different_translator.id)
          expect(auths.first['role']).to eq('translator')
        end
      end
    end

    describe '#review' do
      subject(:call) { get :review, params: { id: ingestible.id } }

      let(:translator) { create(:authority) }
      let(:author1) { create(:authority) }
      let(:author2) { create(:authority) }
      let(:markdown) { "&&& Work 1\n\nSome content\n\n&&& Work 2\n\nMore content" }
      let(:toc_buffer) do
        # Work 1 has specific author, Work 2 has no specific authorities
        " yes || Work 1 || #{[{ seqno: 1, authority_id: author1.id, authority_name: author1.name,
                                role: 'author' }].to_json} || prose || en || public_domain\n yes || Work 2 || || prose || en || public_domain"
      end
      let(:ingestible) do
        create(:ingestible,
               markdown: markdown,
               toc_buffer: toc_buffer,
               default_authorities: [{ seqno: 1, authority_id: translator.id, authority_name: translator.name,
                                       role: 'translator' }].to_json)
      end

      it 'is successful' do
        expect(call).to be_successful
      end

      it 'uses per-role merging in prep_for_ingestion' do
        call
        authority_changes = controller.instance_variable_get(:@authority_changes)

        # Verify Work 1 has both author and translator (per-role merge)
        expect(authority_changes[author1.name]['author']).to include('Work 1')
        expect(authority_changes[translator.name]['translator']).to include('Work 1')

        # Verify Work 2 has only translator (default)
        expect(authority_changes[translator.name]['translator']).to include('Work 2')
      end

      context 'when checking for missing authorities' do
        it 'does not report missing translator when default translator exists' do
          call
          missing_translators = controller.instance_variable_get(:@missing_translators)

          # Neither work should be missing translator due to per-role merging
          expect(missing_translators).to be_empty
        end

        it 'reports missing author when default does not include author' do
          call
          missing_authors = controller.instance_variable_get(:@missing_authors)

          # Work 2 should be missing author (no default author, no specific author)
          expect(missing_authors).to include('Work 2')
          # Work 1 should not be missing author (has specific author)
          expect(missing_authors).not_to include('Work 1')
        end
      end

      context 'when checking for potential duplicates' do
        let!(:existing_work) { create(:work, title: 'Work 1', orig_lang: 'en', genre: 'prose', author: author1) }
        let!(:existing_expression) do
          create(:expression, work: existing_work, title: 'Work 1', language: 'he', orig_lang: 'en',
                              translator: translator)
        end
        let!(:existing_manifestation) do
          create(:manifestation, expression: existing_expression, title: 'Work 1', author: author1, translator: translator,
                                 orig_lang: 'en')
        end

        it 'detects potential duplicates with same title and authorities' do
          call
          potential_duplicates = controller.instance_variable_get(:@potential_duplicates)

          expect(potential_duplicates).not_to be_empty
          duplicate = potential_duplicates.find { |d| d[:title] == 'Work 1' }
          expect(duplicate).to be_present
          expect(duplicate[:manifestation_id]).to eq(existing_manifestation.id)
        end

        it 'does not report duplicate for works with different authorities' do
          call
          potential_duplicates = controller.instance_variable_get(:@potential_duplicates)

          # Work 2 has different authorities (only translator, no author1)
          work2_duplicate = potential_duplicates.find { |d| d[:title] == 'Work 2' }
          expect(work2_duplicate).to be_nil
        end

        context 'when no duplicates exist' do
          # Don't create existing records in this context
          let!(:existing_work) { nil }
          let!(:existing_expression) { nil }
          let!(:existing_manifestation) { nil }

          it 'returns empty potential_duplicates array' do
            call
            potential_duplicates = controller.instance_variable_get(:@potential_duplicates)
            expect(potential_duplicates).to be_empty
          end
        end
      end
    end

    describe '#ingest' do
      let(:author) { create(:authority) }
      let(:translator) { create(:authority) }
      let(:editor) { create(:authority) }
      let(:collection) { create(:collection, title: 'Test Collection') }
      let(:markdown) { "&&& Work 1\n\nSome content for work 1" }
      let(:toc_buffer) do
        " yes || Work 1 || #{[{ seqno: 1, authority_id: author.id, authority_name: author.name,
                                role: 'author' }].to_json} || prose || fr || public_domain"
      end
      let(:ingestible) do
        create(:ingestible,
               markdown: markdown,
               toc_buffer: toc_buffer,
               prospective_volume_id: collection.id.to_s,
               publisher: 'Test Publisher',
               no_volume: false,
               year_published: '2023',
               collection_authorities: [{ seqno: 1, authority_id: editor.id, authority_name: editor.name,
                                          role: 'editor' }].to_json,
               default_authorities: [{ seqno: 1, authority_id: translator.id, authority_name: translator.name,
                                       role: 'translator' }].to_json)
      end

      before do
        ingestible.update_parsing
      end

      it 'redirects to show page after successful ingestion' do
        post :ingest, params: { id: ingestible.id }
        expect(response).to redirect_to(ingestible_path(ingestible))
        expect(flash[:notice]).to eq(I18n.t('ingestibles.ingest.success'))
      end

      it 'uses collection_authorities for collection involved authorities' do
        post :ingest, params: { id: ingestible.id }
        collection.reload
        # Editor should be linked to collection
        editor_ia = collection.involved_authorities.find_by(authority_id: editor.id, role: 'editor')
        expect(editor_ia).to be_present
      end

      it 'uses default_authorities (not collection_authorities) for text involved authorities' do
        post :ingest, params: { id: ingestible.id }
        manifestation = Manifestation.order(id: :desc).first # load the manifestation we just ingested
        expression = manifestation.expression
        work = expression.work

        # Work should have author (from work-specific)
        work_author = work.involved_authorities.find_by(authority_id: author.id, role: 'author')
        expect(work_author).to be_present

        # Expression should have translator (from default_authorities, merged per role)
        expr_translator = expression.involved_authorities.find_by(authority_id: translator.id, role: 'translator')
        expect(expr_translator).to be_present

        # Expression should NOT have editor (editor is only for collection)
        expr_editor = expression.involved_authorities.find_by(authority_id: editor.id, role: 'editor')
        expect(expr_editor).to be_nil
      end

      it 'does not duplicate collection authorities if they already exist' do
        # Pre-create the editor involved authority on collection
        collection.involved_authorities.create!(authority: editor, role: 'editor')
        initial_count = collection.involved_authorities.count

        post :ingest, params: { id: ingestible.id }
        collection.reload

        # Count should not increase
        expect(collection.involved_authorities.count).to eq(initial_count)
      end

      context 'when calculating copyright status' do
        let(:public_domain_author) { create(:authority, intellectual_property: :public_domain) }
        let(:copyrighted_author) { create(:authority, intellectual_property: :copyrighted) }

        it 'sets intellectual_property to public_domain when all authorities are public domain' do
          # Set up ingestible with public domain author
          updated_toc = " yes || Work 1 || #{[{ seqno: 1, authority_id: public_domain_author.id, authority_name: public_domain_author.name,
                                                role: 'author' }].to_json} || prose || fr || public_domain"
          ingestible.update!(toc_buffer: updated_toc)
          ingestible.update_parsing

          post :ingest, params: { id: ingestible.id }

          manifestation = Manifestation.order(id: :desc).first
          expect(manifestation.expression.intellectual_property).to eq('public_domain')
        end

        it 'uses TOC intellectual_property value when copyright calculation determines work is copyrighted' do
          # Set up ingestible with copyrighted author but by_permission in TOC
          updated_toc = " yes || Work 1 || #{[{ seqno: 1, authority_id: copyrighted_author.id, authority_name: copyrighted_author.name,
                                                role: 'author' }].to_json} || prose || fr || by_permission"
          ingestible.update!(toc_buffer: updated_toc)
          ingestible.update_parsing

          post :ingest, params: { id: ingestible.id }

          manifestation = Manifestation.order(id: :desc).first
          expect(manifestation.expression.intellectual_property).to eq('by_permission')
        end

        it 'falls back to ingestible intellectual_property when TOC value is blank and work is copyrighted' do
          # Set up ingestible with copyrighted author, no TOC IP, but ingestible IP
          updated_toc = " yes || Work 1 || #{[{ seqno: 1, authority_id: copyrighted_author.id, authority_name: copyrighted_author.name,
                                                role: 'author' }].to_json} || prose || fr || "
          ingestible.update!(toc_buffer: updated_toc, intellectual_property: 'copyrighted')
          ingestible.update_parsing

          post :ingest, params: { id: ingestible.id }

          manifestation = Manifestation.order(id: :desc).first
          expect(manifestation.expression.intellectual_property).to eq('copyrighted')
        end

        it 'uses by_permission as ultimate fallback when everything else is blank' do
          # Set up ingestible with copyrighted author, no IP values anywhere
          updated_toc = " yes || Work 1 || #{[{ seqno: 1, authority_id: copyrighted_author.id, authority_name: copyrighted_author.name,
                                                role: 'author' }].to_json} || prose || fr || "
          ingestible.update!(toc_buffer: updated_toc, intellectual_property: nil)
          ingestible.update_parsing

          post :ingest, params: { id: ingestible.id }

          manifestation = Manifestation.order(id: :desc).first
          expect(manifestation.expression.intellectual_property).to eq('by_permission')
        end
      end

      it 'calls recalc_cached_people! on created manifestations' do
        expect_any_instance_of(Manifestation).to receive(:recalc_cached_people!)
        post :ingest, params: { id: ingestible.id }
      end

      it 'calls update_alternate_titles on created manifestations' do
        expect_any_instance_of(Manifestation).to receive(:update_alternate_titles)
        post :ingest, params: { id: ingestible.id }
      end

      it 'removes markdown escape backslashes from titles during ingestion' do
        # Create ingestible with title containing escaped brackets
        brackets_markdown = "&&& \\[Test Work\\]\n\nContent with brackets in title"
        brackets_toc = " yes || \\[Test Work\\] || #{[{ seqno: 1, authority_id: author.id, authority_name: author.name,
                                                        role: 'author' }].to_json} || prose || fr || public_domain"
        brackets_ingestible = create(:ingestible,
                                     markdown: brackets_markdown,
                                     toc_buffer: brackets_toc,
                                     prospective_volume_id: collection.id.to_s,
                                     publisher: 'Test Publisher',
                                     no_volume: false,
                                     year_published: '2023',
                                     default_authorities: [{ seqno: 1, authority_id: translator.id,
                                                             authority_name: translator.name,
                                                             role: 'translator' }].to_json)
        brackets_ingestible.update_parsing

        expect do
          post :ingest, params: { id: brackets_ingestible.id, confirm_duplicates: '1' }
        end.to change(Manifestation, :count).by(1)

        manifestation = Manifestation.order(id: :desc).first
        expression = manifestation.expression
        work = expression.work

        # Verify that titles don't have escape backslashes
        expect(work.title).to eq('[Test Work]')
        expect(expression.title).to eq('[Test Work]')
        expect(manifestation.title).to eq('[Test Work]')
      end

      it 'detects duplicates when ingesting escaped bracket titles matching existing unescaped titles' do
        # First, create an existing manifestation with unescaped title
        existing_work = create(:work, title: '[Existing Work]', orig_lang: 'fr', genre: 'prose', author: author)
        existing_expression = create(:expression, work: existing_work, title: '[Existing Work]', language: 'he',
                                                  orig_lang: 'fr', translator: translator)
        existing_manifestation = create(:manifestation, expression: existing_expression, title: '[Existing Work]',
                                                        author: author, translator: translator, orig_lang: 'fr')

        # Now try to ingest a text with the ESCAPED version of the same title
        brackets_markdown = "&&& \\[Existing Work\\]\n\nContent with brackets"
        brackets_toc = " yes || \\[Existing Work\\] || #{[{ seqno: 1, authority_id: author.id, authority_name: author.name,
                                                            role: 'author' }].to_json} || prose || fr || public_domain"
        brackets_ingestible = create(:ingestible,
                                     markdown: brackets_markdown,
                                     toc_buffer: brackets_toc,
                                     prospective_volume_id: collection.id.to_s,
                                     publisher: 'Test Publisher',
                                     no_volume: false,
                                     year_published: '2023',
                                     default_authorities: [{ seqno: 1, authority_id: translator.id,
                                                             authority_name: translator.name,
                                                             role: 'translator' }].to_json)
        brackets_ingestible.update_parsing

        # Ingestion should be blocked due to duplicate detection
        post :ingest, params: { id: brackets_ingestible.id, confirm_duplicates: '0' }

        expect(response).to redirect_to(review_ingestible_path(brackets_ingestible))
        expect(flash[:alert]).to eq(I18n.t('ingestibles.ingest.duplicates_found_not_confirmed'))

        # Verify the duplicate was detected
        potential_duplicates = controller.instance_variable_get(:@potential_duplicates)
        expect(potential_duplicates).not_to be_empty
        duplicate = potential_duplicates.find { |d| d[:title] == '[Existing Work]' }
        expect(duplicate).to be_present
        expect(duplicate[:manifestation_id]).to eq(existing_manifestation.id)
      end

      it 'updates cached_people field on manifestations after ingestion' do
        post :ingest, params: { id: ingestible.id }

        manifestation = Manifestation.order(id: :desc).first
        # Verify that cached_people was set to the author string
        expected_author_string = manifestation.author_string!
        expect(manifestation.cached_people).to eq(expected_author_string)
      end

      context 'test alternate titles population' do
        let(:markdown) { "&&& מִטָה ושֻׁלְחָן\n\nSome content for work 1" }
        let(:toc_buffer) do
          " yes || מִטָה ושֻׁלְחָן || #{[{ seqno: 1, authority_id: author.id, authority_name: author.name,
                                           role: 'author' }].to_json} || prose || fr || public_domain"
        end

        it 'populates alternate_titles field on manifestations after ingestion' do
          post :ingest, params: { id: ingestible.id }

          manifestation = Manifestation.order(id: :desc).first
          expect(manifestation.alternate_titles).to eq('מטה ושלחן; מיטה ושולחן')
        end
      end

      context 'when creating volume from Publication' do
        let(:publication) { create(:publication, title: 'Original Publication Title') }
        let(:markdown) { "&&& Work 1\n\nSome content for work 1" }
        let(:toc_buffer) do
          " yes || Work 1 || #{[{ seqno: 1, authority_id: author.id, authority_name: author.name,
                                  role: 'author' }].to_json} || prose || fr || public_domain"
        end

        context 'when prospective_volume_title is not provided' do
          let(:ingestible) do
            create(:ingestible,
                   markdown: markdown,
                   toc_buffer: toc_buffer,
                   prospective_volume_id: "P#{publication.id}",
                   prospective_volume_title: nil,
                   publisher: 'Test Publisher',
                   no_volume: false,
                   year_published: '2023',
                   default_authorities: [{ seqno: 1, authority_id: translator.id, authority_name: translator.name,
                                           role: 'translator' }].to_json)
          end

          it 'creates volume with publication title' do
            ingestible.update_parsing
            post :ingest, params: { id: ingestible.id }

            created_collection = Collection.find_by(publication: publication)
            expect(created_collection).to be_present
            expect(created_collection.title).to eq('Original Publication Title')
          end
        end

        context 'when prospective_volume_title is provided (edited by user)' do
          let(:ingestible) do
            create(:ingestible,
                   markdown: markdown,
                   toc_buffer: toc_buffer,
                   prospective_volume_id: "P#{publication.id}",
                   prospective_volume_title: 'Edited Volume Title',
                   publisher: 'Test Publisher',
                   no_volume: false,
                   year_published: '2023',
                   default_authorities: [{ seqno: 1, authority_id: translator.id, authority_name: translator.name,
                                           role: 'translator' }].to_json)
          end

          it 'creates volume with edited title from prospective_volume_title' do
            ingestible.update_parsing
            post :ingest, params: { id: ingestible.id }

            created_collection = Collection.find_by(publication: publication)
            expect(created_collection).to be_present
            expect(created_collection.title).to eq('Edited Volume Title')
          end

          it 'does not change the Publication title' do
            ingestible.update_parsing
            original_pub_title = publication.title
            post :ingest, params: { id: ingestible.id }

            publication.reload
            expect(publication.title).to eq(original_pub_title)
          end
        end
      end

      context 'when potential duplicates exist' do
        let!(:existing_work) { create(:work, title: 'Work 1', orig_lang: 'fr', genre: 'prose', author: author) }
        let!(:existing_expression) do
          create(:expression, work: existing_work, title: 'Work 1', language: 'he', orig_lang: 'fr',
                              translator: translator)
        end
        let!(:existing_manifestation) do
          create(:manifestation, expression: existing_expression, title: 'Work 1', author: author, translator: translator,
                                 orig_lang: 'fr')
        end

        before do
          ingestible.update_parsing
        end

        context 'when confirm_duplicates is not checked' do
          it 'blocks ingestion and redirects to review with alert' do
            post :ingest, params: { id: ingestible.id, confirm_duplicates: '0' }
            expect(response).to redirect_to(review_ingestible_path(ingestible))
            expect(flash[:alert]).to eq(I18n.t('ingestibles.ingest.duplicates_found_not_confirmed'))
          end

          it 'does not create new manifestation' do
            expect do
              post :ingest, params: { id: ingestible.id, confirm_duplicates: '0' }
            end.not_to change(Manifestation, :count)
          end
        end

        context 'when confirm_duplicates is checked' do
          it 'allows ingestion to proceed' do
            post :ingest, params: { id: ingestible.id, confirm_duplicates: '1' }
            expect(response).to redirect_to(ingestible_path(ingestible))
            expect(flash[:notice]).to eq(I18n.t('ingestibles.ingest.success'))
          end

          it 'creates new manifestation despite duplicate' do
            expect do
              post :ingest, params: { id: ingestible.id, confirm_duplicates: '1' }
            end.to change(Manifestation, :count).by(1)
          end
        end

        context 'when confirm_duplicates param is not present' do
          it 'blocks ingestion (treats missing param as not confirmed)' do
            post :ingest, params: { id: ingestible.id }
            expect(response).to redirect_to(review_ingestible_path(ingestible))
            expect(flash[:alert]).to eq(I18n.t('ingestibles.ingest.duplicates_found_not_confirmed'))
          end
        end
      end
    end
  end
end
