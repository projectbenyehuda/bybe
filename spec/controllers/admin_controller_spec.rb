# frozen_string_literal: true

require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

describe AdminController do
  describe '#authors_without_works' do
    subject(:call) { get :authors_without_works }

    include_context 'when editor logged in'

    before do
      create_list(:manifestation, 5)
      create_list(:authority, 3)
      allow(Rails.cache).to receive(:write)
    end

    it 'is successful' do
      expect(call).to be_successful
      expect(Rails.cache).to have_received(:write).with('report_authors_without_works', 3)
    end
  end

  describe '#index' do
    subject { get :index }

    include_context 'Admin user logged in'

    before do
      %w(
        bib_workshop
        handle_proofs
        moderate_tags
        handle_recommendations
        edit_sitenotice
        curate_featured_content
        conversion_verification
      ).each { |bit| ListItem.create!(listkey: bit, item: admin) }
    end

    let(:assigned_proof) { create(:proof, status: :assigned) }
    let!(:assignment) { create(:list_item, user: admin, listkey: 'proofs_by_user', item: assigned_proof) }

    it { is_expected.to be_successful }
  end

  describe '#periodless' do
    subject(:call) { get :periodless }

    include_context 'when editor logged in'

    let(:periodless_hebrew) { create(:authority, period: nil) }
    let(:periodless_foreign) { create(:authority, period: nil) }

    before do
      create_list(:authority, 5)
      create_list(:manifestation, 5, orig_lang: 'he', author: periodless_hebrew)
      create_list(:manifestation, 5, orig_lang: 'ru', author: periodless_foreign)
      allow(Rails.cache).to receive(:write)
    end

    it 'completes successfully' do
      expect(call).to be_successful
      expect(assigns(:authors)).to contain_exactly(periodless_hebrew)
      expect(Rails.cache).to have_received(:write).with('report_periodless', 1)
    end
  end

  describe '#missing_genre' do
    subject { get :missing_genres }

    context 'when admin user is authorized' do
      include_context 'Admin user logged in'

      it { is_expected.to be_successful }
    end
  end

  describe '#suspicious_headings' do
    subject { get :suspicious_headings }

    include_context 'Admin user logged in'

    before do
      create(:manifestation, cached_heading_lines: '1|2|3|4', markdown: "Some\nmultiline\ntext\nfor\n\test")
    end

    it { is_expected.to be_successful }
  end

  describe '#slash_in_titles' do
    subject(:call) { get :slash_in_titles }

    include_context 'when editor logged in'

    before do
      create(:collection, title: 'Collection with / slash')
      create(:collection, title: 'Collection with \\ backslash')
      create(:work, title: 'Work with / slash')
      create(:expression, title: 'Expression with \\ backslash')
      create(:manifestation, title: 'Manifestation with / slash') # also entails creating an Expression with the same title
      # create some without slashes
      create_list(:collection, 2)
      create_list(:work, 2)
      create_list(:expression, 2)
      create_list(:manifestation, 2)
      allow(Rails.cache).to receive(:write)
    end

    it 'completes successfully and finds records with slashes' do
      expect(call).to be_successful
      expect(assigns(:collections).count).to eq(2)
      expect(assigns(:works).count).to eq(1)
      expect(assigns(:expressions).count).to eq(2) # one created with Manifestation
      expect(assigns(:manifestations).count).to eq(1)
      expect(assigns(:total)).to eq(6)
      expect(Rails.cache).to have_received(:write).with('report_slash_in_titles', 6)
    end

    context 'with whitelisted items' do
      let!(:whitelisted_collection) { create(:collection, title: 'Whitelisted / Collection') }
      let!(:whitelisted_manifestation) { create(:manifestation, title: 'Whitelisted / Manifestation') }

      before do
        ListItem.create!(listkey: 'title_slashes_okay', item: whitelisted_collection)
        ListItem.create!(listkey: 'title_slashes_okay', item: whitelisted_manifestation)
      end

      it 'excludes whitelisted items from results' do
        expect(call).to be_successful
        expect(assigns(:collections)).not_to include(whitelisted_collection)
        expect(assigns(:manifestations)).not_to include(whitelisted_manifestation)
      end
    end
  end

  describe '#mark_slash_title_as_okay' do
    subject(:call) { get :mark_slash_title_as_okay, params: { item_type: item_type, id: item.id } }

    include_context 'when editor logged in'

    context 'with a manifestation' do
      let(:item_type) { 'Manifestation' }
      let(:item) { create(:manifestation, title: 'Test / Title') }

      it 'creates a whitelist entry' do
        expect { call }.to change { ListItem.where(listkey: 'title_slashes_okay').count }.by(1)
        expect(call).to be_successful
      end
    end

    context 'with a collection' do
      let(:item_type) { 'Collection' }
      let(:item) { create(:collection, title: 'Test / Collection') }

      it 'creates a whitelist entry' do
        expect { call }.to change { ListItem.where(listkey: 'title_slashes_okay').count }.by(1)
        expect(call).to be_successful
      end
    end
  end

  describe '#tocs_missing_links' do
    subject { get :tocs_missing_links }

    let(:toc) { create(:toc) }
    let(:author) { create(:authority, toc: toc) }

    before do
      create_list(:manifestation, 3, author: author)
      create_list(:manifestation, 3, orig_lang: 'ru', translator: author)
    end

    include_context 'Admin user logged in'

    it { is_expected.to be_successful }
  end

  describe '#incongruous_copyright' do
    subject(:request) { get :incongruous_copyright }

    include_context 'Admin user logged in'

    let(:copyrighted_author) { create(:authority, intellectual_property: :copyrighted) }
    let(:by_permission_author) { create(:authority, intellectual_property: :permission_for_selected) }
    let(:public_domain_author) { create(:authority, intellectual_property: :public_domain) }

    let!(:public_domain) do
      create(
        :manifestation,
        orig_lang: 'he',
        intellectual_property: :public_domain,
        author: public_domain_author
      )
    end

    let!(:public_domain_translated) do
      create(
        :manifestation,
        orig_lang: 'ru',
        intellectual_property: :public_domain,
        translator: public_domain_author,
        author: public_domain_author
      )
    end

    let!(:by_permission_translated) do
      create(
        :manifestation,
        orig_lang: 'ru',
        intellectual_property: :by_permission,
        translator: by_permission_author,
        author: public_domain_author
      )
    end

    let!(:wrong_public_domain) do
      create(
        :manifestation,
        orig_lang: 'he',
        intellectual_property: :public_domain,
        author: copyrighted_author
      )
    end

    let!(:wrong_public_domain_translated) do
      create(
        :manifestation,
        orig_lang: 'de',
        intellectual_property: :public_domain,
        author: public_domain_author,
        translator: by_permission_author
      )
    end

    let!(:wrong_by_permission) do
      create(
        :manifestation,
        orig_lang: 'he',
        intellectual_property: :by_permission,
        author: public_domain_author
      )
    end

    let!(:wrong_copyrighted_translated) do
      create(
        :manifestation,
        orig_lang: 'de',
        intellectual_property: :copyrighted,
        author: public_domain_author,
        translator: public_domain_author
      )
    end

    let(:wrong_manifestation_ids) do
      [
        wrong_public_domain.id,
        wrong_public_domain_translated.id,
        wrong_by_permission.id,
        wrong_copyrighted_translated.id
      ]
    end

    it 'renders successfully' do
      expect(request).to be_successful
      expect(assigns(:incong).map(&:id)).to match_array wrong_manifestation_ids
    end
  end

  describe '#missing_languages' do
    subject(:request) { get :missing_languages }

    include_context 'Admin user logged in'

    # Reduced from 60 to 5 - just need to verify endpoint works, not stress test it
    before do
      create_list(:manifestation, 5, language: 'ru', orig_lang: 'he')
    end

    it { is_expected.to be_successful }
  end

  describe '#suspicious_titles' do
    subject(:call) { get :suspicious_titles }

    include_context 'Admin user logged in'

    let!(:suspicious_titles) do
      [
        create(:manifestation, title: 'קבוצה א'),
        create(:manifestation, title: 'Trailing dot.')
      ]
    end

    before do
      create_list(:manifestation, 5)
      allow(Rails.cache).to receive(:write)
    end

    it 'completes successfully' do
      expect(call).to be_successful
      expect(Rails.cache).to have_received(:write).with('report_suspicious_titles', suspicious_titles.length)
      expect(assigns(:suspicious)).to match_array suspicious_titles
    end
  end

  describe '#suspicious_translations' do
    subject(:request) { get :suspicious_translations }

    include_context 'Admin user logged in'

    let(:translator) { create(:authority) }

    before do
      create(:manifestation, language: 'he', orig_lang: 'de', author: translator, translator: translator)
      create(:manifestation, language: 'he', orig_lang: 'de', author: translator, translator: translator)
      create(:manifestation, language: 'he', orig_lang: 'en', translator: translator)
    end

    it { is_expected.to be_successful }
  end

  describe '#missing_copyright' do
    subject(:request) { get :missing_copyright }

    include_context 'Admin user logged in'

    let!(:unknown_authority) { create(:authority, intellectual_property: :unknown) }

    let!(:by_permission_manifestation) { create(:manifestation, intellectual_property: :by_permission) }
    let!(:public_domain_manifestation) { create(:manifestation, intellectual_property: :public_domain) }
    let!(:unknown_manifestations) { create_list(:manifestation, 3, intellectual_property: :unknown) }

    before do
      allow(Rails.cache).to receive(:write)
    end

    it 'shows records where copyright is nil' do
      expect(request).to be_successful
      expect(assigns(:mans)).to eq unknown_manifestations
      expect(assigns(:authors)).to eq [unknown_authority]
      expect(Rails.cache).to have_received(:write).with('report_missing_copyright', unknown_manifestations.length)
    end
  end

  describe '#translated_from_multiple_languages' do
    subject(:request) { get :translated_from_multiple_languages }

    include_context 'Admin user logged in'

    let(:author) { create(:authority) }
    let!(:german_works) { create_list(:manifestation, 3, orig_lang: :de, author: author) }
    let!(:russian_works) { create_list(:manifestation, 5, orig_lang: :ru, author: author) }
    let!(:hebrew_works) { create_list(:manifestation, 2, orig_lang: :he, author: author) }

    before do
      # some additional manifestations to be ignroed
      create_list(:manifestation, 5)
    end

    it 'shows authors having original works in different languages' do
      expect(request).to be_successful
      authors = assigns(:authors)
      expect(authors.length).to eq 1
      expect(authors[0][0]).to eq author
      expect(authors[0][1]).to match_array %w(he ru de)
      expect(authors[0][2]).to eq({ 'he' => hebrew_works, 'ru' => russian_works, 'de' => german_works })
    end
  end

  describe 'Featured author functionality' do
    include_context 'Admin user logged in'

    describe '#featured_author_list' do
      subject { get :featured_author_list }

      before do
        create_list(:featured_author, 3)
      end

      it { is_expected.to be_successful }
    end

    describe '#featured_author_new' do
      subject { get :featured_author_new }

      it { is_expected.to be_successful }
    end

    describe '#featured_author_create' do
      subject(:call) { post :featured_author_create, params: create_params }

      let(:person) { create(:authority).person }

      context 'when params are valid' do
        let(:create_params) do
          {
            featured_author: {
              title: 'Title',
              body: 'Body'
            },
            person_id: person.id
          }
        end

        it 'creates record' do
          expect { call }.to change(FeaturedAuthor, :count).by(1)
          fa = FeaturedAuthor.order(id: :desc).first
          expect(fa).to have_attributes(title: 'Title', body: 'Body', person_id: person.id, user: admin)
          expect(call).to redirect_to featured_author_show_path(fa)
        end
      end
    end

    describe 'Member actions' do
      let!(:featured_author) { create(:featured_author) }

      describe '#featured_author_show' do
        subject { get :featured_author_show, params: { id: featured_author.id } }

        it { is_expected.to be_successful }
      end

      describe '#featured_author_edit' do
        subject { get :featured_author_edit, params: { id: featured_author.id } }

        it { is_expected.to be_successful }
      end

      describe '#featured_author_update' do
        subject(:call) do
          post :featured_author_update, params: { id: featured_author.id, featured_author: update_params }
        end

        let(:update_params) do
          {
            title: 'New Title',
            body: 'New Body'
          }
        end

        it 'updates record' do
          expect(call).to redirect_to featured_author_show_path(featured_author)
          featured_author.reload
          expect(featured_author).to have_attributes(update_params)
        end
      end

      describe '#featured_author_destroy' do
        subject(:call) { delete :featured_author_destroy, params: { id: featured_author.id } }

        it 'deletes record' do
          expect { call }.to change(FeaturedAuthor, :count).by(-1)
          expect(call).to redirect_to admin_featured_author_list_path
        end
      end
    end
  end

  describe 'Tagging functionality' do
    include_context 'when editor logged in', :moderate_tags

    let(:tag) { create(:tag, status: tag_status) }
    let(:manifestation) { create(:manifestation) }
    let(:authority) { manifestation.authors.first }
    let(:tag_status) { :approved }

    describe '#tag_moderation' do
      subject { get :tag_moderation }

      let!(:pending_tag) { create(:tag, status: :pending) }
      let!(:pending_manifestation_tagging) { create(:tagging, tag: tag, taggable: manifestation, status: :pending) }
      let!(:pending_authority_tagging) { create(:tagging, tag: tag, taggable: authority, status: :pending) }

      before do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
      end

      after do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
      end

      it { is_expected.to be_successful }

      context 'when pending tags have no taggings' do
        let!(:tag_with_no_taggings) { create(:tag, status: :pending, taggings_count: 0) }
        let!(:tag_with_taggings) { create(:tag, status: :pending) }
        let!(:tagging_for_tag_with_taggings) { create(:tagging, tag: tag_with_taggings, status: :pending) }

        it 'excludes tags with zero taggings from pending_tags' do
          subject
          expect(assigns(:pending_tags)).not_to include(tag_with_no_taggings)
          expect(assigns(:pending_tags)).to include(tag_with_taggings)
        end
      end
    end

    describe '#tag_review' do
      subject { get :tag_review, params: { id: tag.id } }

      let(:tag_status) { :pending }

      before do
        create(:tagging, tag: tag, taggable: manifestation)
        create(:tagging, tag: tag, taggable: authority)

        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
      end

      after do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
      end

      it { is_expected.to be_successful }
    end

    describe '#tagging_review' do
      subject { get :tagging_review, params: { id: tagging.id } }

      let(:tagging) { create(:tagging, tag: tag, taggable: taggable) }

      context 'when Authority' do
        let(:taggable) { authority }

        it { is_expected.to be_successful }

        context 'when TOC does not exists' do
          before do
            authority.toc = nil
            authority.save!
          end

          it { is_expected.to be_successful }
        end
      end

      context 'when Manifestation' do
        let(:taggable) { manifestation }

        it { is_expected.to be_successful }
      end
    end

    describe '#undo_reject_tag' do
      subject(:call) { post :undo_reject_tag, params: { id: tag.id } }

      let(:tag) { create(:tag, status: :rejected) }

      before do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
        File.write(TAGGING_LOCK, current_user.id.to_s)
      end

      after do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
      end

      it 'unrejects the tag' do
        expect { call }.to change { tag.reload.status }.from('rejected').to('pending')
      end

      it 'returns JSON with tag info' do
        call
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to include('tag_id' => tag.id, 'tag_name' => tag.name)
      end
    end

    describe '#undo_approve_tagging' do
      subject(:call) { post :undo_approve_tagging, params: { id: tagging.id } }

      include_context 'when editor logged in', :moderate_tags

      let(:tagging) { create(:tagging, status: :approved, approved_by: current_user.id) }

      before do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
        File.write(TAGGING_LOCK, current_user.id.to_s)
      end

      after do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
      end

      it 'sets tagging status to pending' do
        expect { call }.to change { tagging.reload.status }.from('approved').to('pending')
      end

      it 'clears the approved_by field' do
        expect { call }.to change { tagging.reload.approved_by }.to(nil)
      end

      it 'returns JSON with tagging info' do
        call
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to include('tagging_id' => tagging.id)
      end
    end

    describe '#undo_reject_tagging' do
      subject(:call) { post :undo_reject_tagging, params: { id: tagging.id } }

      include_context 'when editor logged in', :moderate_tags

      let(:tagging) { create(:tagging, status: :rejected, approved_by: current_user.id) }

      before do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
        File.write(TAGGING_LOCK, current_user.id.to_s)
      end

      after do
        File.delete(TAGGING_LOCK) if File.file?(TAGGING_LOCK)
      end

      it 'sets tagging status to pending' do
        expect { call }.to change { tagging.reload.status }.from('rejected').to('pending')
      end

      it 'clears the approved_by field' do
        expect { call }.to change { tagging.reload.approved_by }.to(nil)
      end

      it 'returns JSON with tagging info' do
        call
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to include('tagging_id' => tagging.id)
      end
    end
  end

  describe '#assign_proofs' do
    subject(:call) { post :assign_proofs, params: { proof_id: proof.id } }

    include_context 'when editor logged in', :handle_proofs

    let(:manifestation) { create(:manifestation) }
    let!(:proof) { create(:proof, item: manifestation, status: 'new', created_at: 5.hours.ago) }
    let!(:other_proofs) { create_list(:proof, 3, status: 'new', created_at: 4.hours.ago) }
    let!(:second_proof) { create(:proof, item: manifestation, status: 'new', created_at: 2.hours.ago) }

    it 'assigns all proofs related to same work to current user' do
      expect { call }.to change { ListItem.where(user: current_user, listkey: 'proofs_by_user').count }.by(2)
      expect(call).to redirect_to admin_index_path
      expect(proof.reload.status).to eq('assigned')
      expect(second_proof.reload.status).to eq('assigned')
    end
  end

  describe '#first_manifestations_between_dates' do
    subject(:call) do
      get :first_manifestations_between_dates, params: { from: from_date.to_s, to: to_date.to_s }
    end

    include_context 'when editor logged in'

    let(:from_date) { Date.new(2023, 1, 1) }
    let(:to_date) { Date.new(2023, 12, 31) }

    let!(:authority_with_first_in_range) { create(:authority) }
    let!(:authority_with_first_before_range) { create(:authority) }
    let!(:authority_with_first_after_range) { create(:authority) }
    let!(:authority_without_manifestations) { create(:authority) }

    before do
      # Authority with first manifestation in date range
      travel_to from_date + 3.months do
        create(:manifestation, author: authority_with_first_in_range, orig_lang: 'he')
      end

      # Authority with first manifestation before date range
      travel_to from_date - 1.year do
        create(:manifestation, author: authority_with_first_before_range, orig_lang: 'he')
      end

      # Authority with first manifestation after date range
      travel_to to_date + 1.month do
        create(:manifestation, author: authority_with_first_after_range, orig_lang: 'he')
      end
    end

    it 'returns only authorities with first manifestation in date range' do
      expect(call).to be_successful
      expect(assigns(:authorities).map(&:first)).to contain_exactly(authority_with_first_in_range)
      expect(assigns(:total)).to eq(1)
    end
  end

  describe 'Tag editing functionality' do
    include_context 'when editor logged in', 'moderate_tags'

    let(:tag) { create(:tag, status: :approved, name: 'Test Tag') }
    let!(:tag_name2) { create(:tag_name, tag: tag, name: 'Alternative Name') }

    describe '#edit_tag' do
      subject(:call) { get :edit_tag, params: { id: tag.id } }

      context 'when user has moderate_tags permission' do
        it 'renders the edit page' do
          expect(call).to be_successful
          expect(assigns(:tag)).to eq(tag)
          expect(assigns(:tag_names).count).to eq(2)
          expect(assigns(:tag_names).pluck(:name)).to contain_exactly('Test Tag', 'Alternative Name')
        end
      end

      context 'when tag does not exist' do
        it 'redirects with error' do
          expect { get :edit_tag, params: { id: 99999 } }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    describe '#update_tag' do
      subject(:call) { post :update_tag, params: { id: tag.id, tag_name: new_name, status: new_status } }

      let(:new_name) { 'Updated Tag Name' }
      let(:new_status) { 'pending' }

      context 'when updating tag name' do
        it 'updates the tag and its first TagName' do
          expect { call }.to change { tag.reload.name }.to(new_name)
          expect(tag.tag_names.first.name).to eq(new_name)
          expect(flash[:notice]).to eq(I18n.t(:tag_updated))
        end
      end

      context 'when updating status' do
        let(:new_name) { tag.name }
        let(:new_status) { 'escalated' }

        it 'updates the tag status' do
          expect { call }.to change { tag.reload.status }.to('escalated')
          expect(flash[:notice]).to eq(I18n.t(:tag_updated))
        end
      end

    end

    describe '#add_tag_name' do
      subject(:call) { post :add_tag_name, params: { id: tag.id, tag_name: new_alias } }

      let(:new_alias) { 'New Alias' }

      context 'when adding a new unique alias' do
        it 'creates a new TagName' do
          expect { call }.to change { tag.tag_names.count }.by(1)
          expect(tag.tag_names.pluck(:name)).to include(new_alias)
          expect(flash[:notice]).to eq(I18n.t(:tag_name_added))
        end
      end

      context 'when alias already exists' do
        let(:existing_tag_name) { create(:tag_name, name: 'Existing Name') }
        let(:new_alias) { existing_tag_name.name }

        it 'does not create duplicate and shows error' do
          expect { call }.not_to change { tag.tag_names.count }
          expect(flash[:error]).to eq(I18n.t(:tag_name_already_exists))
        end
      end

    end

    describe '#remove_tag_name' do
      subject(:call) { delete :remove_tag_name, params: { id: tag_name2.id } }

      context 'when removing a non-primary TagName' do
        it 'removes the TagName' do
          expect { call }.to change { tag.tag_names.count }.by(-1)
          expect { tag_name2.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect(flash[:notice]).to eq(I18n.t(:tag_name_removed))
        end
      end

      context 'when trying to remove the last TagName' do
        before { tag_name2.destroy }

        it 'does not remove and shows error' do
          delete :remove_tag_name, params: { id: tag.tag_names.first.id }
          expect(tag.tag_names.count).to eq(1)
          expect(flash[:error]).to eq(I18n.t(:cannot_remove_last_tag_name))
        end
      end

    end
  end

  describe '#duplicate_works' do
    subject(:call) { get :duplicate_works }

    include_context 'when editor logged in'

    let(:author) { create(:authority) }
    let(:translator1) { create(:authority) }
    let(:translator2) { create(:authority) }
    let(:translator3) { create(:authority) }

    before do
      allow(Rails.cache).to receive(:write)
    end

    context 'when there are duplicate works' do
      let!(:expr1) do
        create(:expression,
               title: 'Same Title',
               language: 'he',
               orig_lang: 'en',
               author: author,
               translator: translator1)
      end

      let!(:expr2) do
        create(:expression,
               title: 'Same Title',
               language: 'he',
               orig_lang: 'en',
               author: author,
               translator: translator2)
      end

      it 'finds duplicate work clusters' do
        call
        expect(assigns(:duplicate_clusters).length).to eq(1)
        cluster_expressions = assigns(:duplicate_clusters).values.first
        expect(cluster_expressions).to contain_exactly(expr1, expr2)
        expect(Rails.cache).to have_received(:write).with('report_duplicate_works', 1)
      end
    end

    context 'when expressions have the same translator' do
      let!(:expr1) do
        create(:expression,
               title: 'Same Title',
               language: 'he',
               orig_lang: 'en',
               author: author,
               translator: translator1)
      end

      let!(:expr2) do
        create(:expression,
               title: 'Same Title',
               language: 'he',
               orig_lang: 'en',
               author: author,
               translator: translator1)
      end

      it 'does not include them as duplicates' do
        call
        expect(assigns(:duplicate_clusters).length).to eq(0)
        expect(Rails.cache).to have_received(:write).with('report_duplicate_works', 0)
      end
    end

    context 'when there are no duplicate works' do
      before do
        create(:expression, title: 'Unique Title 1', translation: true)
        create(:expression, title: 'Unique Title 2', translation: true)
      end

      it 'returns empty clusters' do
        call
        expect(assigns(:duplicate_clusters)).to be_empty
        expect(Rails.cache).to have_received(:write).with('report_duplicate_works', 0)
      end
    end
  end

  describe '#merge_works' do
    include_context 'when editor logged in'

    let(:author) { create(:authority) }
    let(:translator1) { create(:authority) }
    let(:translator2) { create(:authority) }
    let(:user) { create(:user) }

    let!(:source_expr) do
      create(:expression,
             title: 'Same Title',
             language: 'he',
             orig_lang: 'en',
             author: author,
             translator: translator1)
    end

    let!(:target_expr) do
      create(:expression,
             title: 'Same Title',
             language: 'he',
             orig_lang: 'en',
             author: author,
             translator: translator2)
    end

    let(:source_work) { source_expr.work }
    let(:target_work) { target_expr.work }

    let!(:aboutness1) { create(:aboutness, work: source_work, user: user) }
    let!(:aboutness2) { create(:aboutness, work: source_work, user: user) }

    subject(:call) do
      post :merge_works, params: {
        source_work_id: source_work.id,
        target_work_id: target_work.id
      }
    end

    it 'merges the source work into the target work' do
      call
      expect { source_work.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(source_expr.reload.work).to eq(target_work)
      expect(target_work.reload.expressions).to contain_exactly(source_expr, target_expr)
    end

    it 'reassociates aboutnesses to target work' do
      call
      expect(aboutness1.reload.work_id).to eq(target_work.id)
      expect(aboutness2.reload.work_id).to eq(target_work.id)
      expect(target_work.reload.topics.count).to eq(2)
    end

    it 'redirects with success message' do
      call
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('/admin/duplicate_works')
    end

    context 'when request format is JS' do
      subject(:call) do
        post :merge_works, params: {
          source_work_id: source_work.id,
          target_work_id: target_work.id
        }, format: :js
      end

      it 'returns success status' do
        call
        expect(response).to be_successful
        expect(assigns(:success)).to be true
        expect(assigns(:message)).to eq(I18n.t(:works_merged_successfully))
      end

      it 'merges the works' do
        call
        expect { source_work.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(source_expr.reload.work).to eq(target_work)
      end
    end

    context 'when source work does not exist' do
      subject(:call) do
        post :merge_works, params: {
          source_work_id: 99999,
          target_work_id: target_work.id
        }, format: :html
      end

      it 'redirects with error message' do
        call
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/admin/duplicate_works')
      end

      context 'when request format is JS' do
        subject(:call) do
          post :merge_works, params: {
            source_work_id: 99999,
            target_work_id: target_work.id
          }, format: :js
        end

        it 'returns error status' do
          call
          expect(response).to be_successful
          expect(assigns(:success)).to be false
          expect(assigns(:message)).to eq(I18n.t(:work_not_found))
        end
      end
    end

    context 'when target work does not exist' do
      let!(:source_only_expr) do
        create(:expression,
               title: 'Another Title',
               language: 'he',
               orig_lang: 'en',
               author: author,
               translator: translator1)
      end

      subject(:call) do
        post :merge_works, params: {
          source_work_id: source_only_expr.work.id,
          target_work_id: 99999
        }
      end

      it 'redirects with error message' do
        call
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/admin/duplicate_works')
      end
    end
  end
end
