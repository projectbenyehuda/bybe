require 'rails_helper'

describe ManifestationController do

  describe '#browse' do
    before(:all) do
      clean_tables
      Chewy.strategy(:atomic) do
        create_list(:manifestation, 10)
      end
    end

    let(:browse_params) { {} }

    subject { get :browse, params: browse_params }

    context 'when user is not logged in' do
      it { is_expected.to be_successful }
    end

    context 'when user is logged in' do
      let!(:user) { create(:user) }
      before do
        session[:user_id] = user.id
      end

      it { is_expected.to be_successful }
    end

    context 'when no params are provided' do
      it { is_expected.to be_successful }
    end

    describe 'passing params to SearchManifestation service' do
      let(:browse_params) do
        {
          ckb_periods: %w(ancient revival),
          ckb_genres: %w(poetry memoir),
          ckb_intellectual_property: %w(orphan unknown),
          ckb_genders: %w(male other),
          ckb_tgenders: %w(female unknown),
          authors: '1,2,3',
          ckb_languages: %w(ru en),
          fromdate: '1980',
          todate: '1995',
          date_type: 'created',
          sort_by: 'alphabetical_desc'
        }
      end

      let(:expected_sort_by) { 'alphabetical' }
      let(:expected_sort_dir) { 'desc' }
      let(:expected_filter) do
        {
          'periods' => %w(ancient revival),
          'genres' => %w(poetry memoir),
          'intellectual_property_types' => %w(orphan unknown),
          'author_genders' => %w(male other),
          'translator_genders' => %w(female unknown),
          'author_ids' => [1, 2, 3],
          'original_languages' => %w(ru en),
          'created_between' => { 'from' => 1980, 'to' => 1995 }
        }
      end

      before do
        expect(SearchManifestations).to receive(:call).
          with(expected_sort_by, expected_sort_dir, expected_filter).and_call_original
      end

      it { is_expected.to be_successful }

      describe 'search queries' do
        let(:author_filter) { { 'author' => 'Jack London' } }
        let(:title_filter) { { 'title' => 'Love to Life' } }

        context 'when title specified' do
          let(:browse_params) { { search_input: 'Love to Life', search_type: 'workname', sort_by: 'alphabetical_desc' } }
          let(:expected_filter) { title_filter }
          it { is_expected.to be_successful }
        end

        context 'when authorname specified' do
          let(:browse_params) { { authorstr: 'Jack London', search_type: 'authorname', sort_by: 'alphabetical_desc' } }
          let(:expected_filter) { author_filter }
          it { is_expected.to be_successful }
        end

        context 'when both authorname and title specified' do
          let(:browse_params) do
            {
              search_input: 'Love to Life',
              authorstr: 'Jack London',
              search_type: search_type,
              sort_by: 'alphabetical_desc'
            }
          end

          context 'when search_type is authorname' do
            let(:search_type) { 'authorname' }
            let(:expected_filter) { author_filter }
            it { is_expected.to be_successful }
          end

          context 'when search_type is workname' do
            let(:search_type) { 'workname' }
            let(:expected_filter) { title_filter }
            it { is_expected.to be_successful }
          end

          context 'when search_type is empty' do
            let(:search_type) { nil }
            let(:expected_filter) { title_filter }
            it { is_expected.to be_successful }
          end
        end
      end

      describe 'sorting' do
        let(:expected_filter) { {} }
        # Simply ensure all sort combinations works
        %w(alphabetical popularity creation_date publication_date upload_date).each do | column |
          %w(asc desc).each do |dir|
            context "when #{dir} sorting by #{column} is requested" do
              let(:expected_sort_by) { column }
              let(:expected_sort_dir) { dir }
              let(:browse_params) { { sort_by: "#{column}_#{dir}" } }
              it { is_expected.to be_successful }
            end
          end
        end
      end
    end

    describe 'paging' do
      let(:browse_params) { { page: page } }

      context 'when page number 0 is requested' do
        let(:page) { 0 }
        it 'returns first page' do
          expect(subject).to be_successful
        end
      end

      context 'when page number is not specified' do
        let(:page) { nil }
        it 'returns first page' do
          expect(subject).to be_successful
        end
      end
    end

    after(:all) do
      clean_tables
    end
  end

  describe '#get_random' do
    before do
      create_list(:manifestation, 5)
    end

    subject { get :get_random, params: { genre: genre } }

    context 'when genre specified' do
      let(:genre) { Work.first.genre }
      it { is_expected.to be_successful }
    end

    context 'when genre is not specified' do
      let(:genre) { nil }
      it { is_expected.to be_successful }
    end
  end

  describe '#whatsnew' do
    subject { get :whatsnew, params: { } }
    before do
      create_list(:manifestation, 5, created_at: 7.days.ago)
    end

    it { is_expected.to be_successful }
  end

  describe '#surprise_work' do
    before do
      create_list(:manifestation, 3)
    end

    subject { get :surprise_work }

    it { is_expected.to be_successful }
  end

  describe '#list' do
    let(:user) { create(:user, :edit_catalog) }
    let!(:manifestation) { create(:manifestation, orig_lang: 'ru') }

    before do
      create_list(:manifestation, 3)
      session[:user_id] = user.id

      Manifestation.all.each do |m|
        m.recalc_cached_people
        m.save!
      end
    end

    subject { get :list, params: { author: author, title: title } }
    let(:author) { nil }
    let(:title) { nil }

    it { is_expected.to be_successful }

    context 'when author is provided' do
      let(:author) { manifestation.authors.first.name }

      it { is_expected.to be_successful }
    end

    context 'when title is provided' do
      let(:title) { manifestation.title }

      it { is_expected.to be_successful }
    end

    context 'when both title and author are provided' do
      let(:author) { manifestation.authors.first.name }
      let(:title) { manifestation.title }

      it { is_expected.to be_successful }
    end
  end

  describe 'member actions' do
    let(:genre) { :memoir }
    let(:title) { 'Some title' }
    let(:orig_lang) { 'he' }
    let!(:manifestation) do
      create(:manifestation, title: title, genre: genre, orig_lang: orig_lang, primary: true)
    end
    let(:expression) { manifestation.expression }
    let(:work) { expression.work }

    describe '#show' do
      subject { get :show, params: { id: manifestation.id } }

      let!(:user) { create(:user, :edit_catalog) }

      before do
        session[:user_id] = user.id
      end

      it { is_expected.to be_successful }
    end

    describe '#read' do
      subject(:call) { get :read, params: { id: manifestation.id } }

      context 'when user is not logged in' do
        it { is_expected.to be_successful }
      end

      context 'when user is logged in' do
        include_context 'when user logged in'

        it { is_expected.to be_successful }
      end

      context 'when it is a translation and work has other translations' do
        let(:orig_lang) { 'ru' }

        let(:other_translation_expression) { create(:expression, language: 'he', work: manifestation.expression.work) }
        let!(:other_translation_manifestation) { create(:manifestation, expression: other_translation_expression) }

        it { is_expected.to be_successful }
      end

      context 'when genre is lexicon and it has dictionary_entries' do
        let(:genre) { :lexicon }
        before do
          create(:dictionary_entry, manifestation: manifestation)
        end

        it { is_expected.to redirect_to dict_browse_path(manifestation.id) }
      end

      context 'when manifestation is in an uncollected collection with no siblings' do
        let(:uncollected_collection) { create(:collection, :uncollected) }
        let(:manifestation) { create(:manifestation, collections: [uncollected_collection]) }

        it 'does not displays collection siblings links' do
          expect(call).to be_successful
          expect(assigns(:containments).size).to eq(1)
          expect(assigns(:containments).first.collection).to eq(uncollected_collection)
          expect(response.body).not_to include(I18n.t(:to_previous_item))
          expect(response.body).not_to include(I18n.t(:to_next_item))
        end
      end

      context 'when manifestation is included both in a volume and in an uncollected collection' do
        let(:uncollected_collection) { create(:collection, :uncollected) }
        let!(:volume_collection) { create(:collection, collection_type: :volume) }
        let(:manifestation) { create(:manifestation, collections: [uncollected_collection, volume_collection]) }

        it 'hides uncollected collection' do
          expect(call).to be_successful
          expect(assigns(:containments).size).to eq(1)
          expect(assigns(:containments).first.collection).to eq(volume_collection)
        end
      end

      context 'when manifestation is in a regular collection with siblings' do
        let!(:regular_collection) do
          create(
            :collection,
            collection_type: :volume,
            manifestations: [prev_manifestation, manifestation, next_manifestation]
          )
        end
        let(:prev_manifestation) { create(:manifestation) }
        let(:next_manifestation) { create(:manifestation) }

        it 'renders both collection navigation links' do
          expect(call).to be_successful
          expect(assigns(:containments)).to be_present
          expect(assigns(:containments).first.collection).to eq(regular_collection)
          expect(response.body).to include(I18n.t(:to_previous_item))
          expect(response.body).to include(I18n.t(:to_next_item))
        end
      end
    end

    describe '#readmode' do
      subject { get :readmode, params: { id: manifestation.id } }

      let(:orig_lang) { 'de' }

      it { is_expected.to be_successful }
    end

    describe '#read with search query parameter' do
      it 'accepts query parameter and renders successfully' do
        get :read, params: { id: manifestation.id, q: 'search term' }
        expect(response).to be_successful
        expect(response.body).to include('actualtext')
      end
    end

    describe '#print' do
      subject { get :print, params: { id: manifestation.id } }

      it { is_expected.to be_successful }
    end

    describe '#edit_metadata' do
      subject { get :edit_metadata, params: { id: manifestation.id } }

      context 'when user is not signed it' do
        it { is_expected.to redirect_to('/') }
      end

      context 'when user is signed in' do
        let(:user) { create(:user, editor: editor_flag) }

        before do
          session[:user_id] = user.id
        end

        context 'when user is not an editor' do
          let(:editor_flag) { false }
          it { is_expected.to redirect_to('/') }
        end

        context 'when user is an editor' do
          let(:editor_flag) { true }
          it { is_expected.to redirect_to('/') }

          context 'when user has edit_catalog bit' do
            let(:user) { create(:user, :edit_catalog) }
            it { is_expected.to be_successful }
          end
        end
      end
    end

    describe '#update' do
      subject(:call) { put :update, params: params.merge(commit: commit, id: manifestation.id) }

      let(:user) { create(:user, :edit_catalog) }

      before do
        session[:user_id] = user.id
      end

      context "when 'save' button pressed" do
        let(:commit) { I18n.t(:save) }

        context 'when markdown is changed' do
          let(:params) { { markdown: 'test', newtitle: 'New Title In Hebrew' } }

          it 'updates markdown and redirects to show page' do
            expect(subject).to redirect_to(manifestation_show_path(manifestation))
            expect(flash.notice).to eq I18n.t(:updated_successfully)

            manifestation.reload
            expect(manifestation).to have_attributes(title: 'New Title In Hebrew', markdown: 'test')
            expect(expression).to have_attributes(title: 'New Title In Hebrew')
          end
        end

        context 'when metadata was changed' do
          let(:params) do
            {
              wtitle: 'New Work Title',
              mtitle: 'New Manifestation Title',
              etitle: 'New Expression Title',
              genre: 'fables',
              wlang: 'ru',
              primary: 'false',
              intellectual_property: 'by_permission'
            }
          end

          it 'updates metadata and redirects to show page' do
            expect(call).to redirect_to(manifestation_show_path(manifestation))
            expect(flash.notice).to eq I18n.t(:updated_successfully)
            manifestation.reload
            expect(manifestation).to have_attributes(title: 'New Manifestation Title')
            expect(expression).to have_attributes(title: 'New Expression Title', intellectual_property: 'by_permission')
            expect(work).to have_attributes(title: 'New Work Title', orig_lang: 'ru', genre: 'fables', primary: false)
          end
        end
      end

      context "when 'preview' button pressed" do
        let(:commit) { I18n.t(:preview) }
        let(:params) { { markdown: 'test' } }

        it { is_expected.to be_successful }
      end
    end

    describe '#dict' do
      let(:genre) { :lexicon }
      before do
        create(:dictionary_entry, manifestation: manifestation)
      end

      subject { get :dict, params: { id: manifestation.id } }

      it { is_expected.to be_successful }

      context 'when genre is not a lexicon' do
        let(:genre) { :memoir }

        it { is_expected.to redirect_to manifestation_path(manifestation) }
      end

      context 'when manifestation is unpublished' do
        before do
          manifestation.update!(status: Manifestation.statuses[:unpublished])
        end

        context 'when user is not logged in' do
          it 'redirects to home with notice' do
            expect(subject).to redirect_to('/')
            expect(flash[:notice]).to eq(I18n.t(:work_not_available))
          end
        end

        context 'when user is logged in but not an editor' do
          let(:user) { create(:user, editor: false) }

          before do
            session[:user_id] = user.id
          end

          it 'redirects to home with notice' do
            expect(subject).to redirect_to('/')
            expect(flash[:notice]).to eq(I18n.t(:work_not_available))
          end
        end

        context 'when user is an editor' do
          let(:user) { create(:user, :edit_catalog) }

          before do
            session[:user_id] = user.id
          end

          it { is_expected.to be_successful }
        end
      end
    end

    describe '#dict_entry' do
      let(:genre) { :lexicon }

      let!(:dictionary_entry) { create(:dictionary_entry, manifestation: manifestation) }

      subject { get :dict_entry, params: { id: manifestation.id, entry: dictionary_entry.id } }

      it { is_expected.to be_successful }

      context 'when manifestation is a translation' do
        let(:orig_lang) { 'de' }

        it { is_expected.to be_successful }
      end

      context 'when manifestation is unpublished' do
        before do
          manifestation.update!(status: Manifestation.statuses[:unpublished])
        end

        context 'when user is not logged in' do
          it 'redirects to home with notice' do
            expect(subject).to redirect_to('/')
            expect(flash[:notice]).to eq(I18n.t(:work_not_available))
          end
        end

        context 'when user is logged in but not an editor' do
          let(:user) { create(:user, editor: false) }

          before do
            session[:user_id] = user.id
          end

          it 'redirects to home with notice' do
            expect(subject).to redirect_to('/')
            expect(flash[:notice]).to eq(I18n.t(:work_not_available))
          end
        end

        context 'when user is an editor' do
          let(:user) { create(:user, :edit_catalog) }

          before do
            session[:user_id] = user.id
          end

          it { is_expected.to be_successful }
        end
      end
    end

    describe '#set_bookmark' do
      let!(:base_user) { create :base_user, session_id: session.id.private_id }
      let(:manifestation) { create(:manifestation) }
      subject { post :set_bookmark, params: { id: manifestation.id, bookmark_path: 'NEW_P' }, format: :js }

      context 'when user already have bookmark in this text' do
        let!(:bookmark) { create(:bookmark, base_user: base_user, manifestation: manifestation) }
        it 'updates record with new bookmark value' do
          expect { subject }.to_not change { Bookmark.count }
          expect(response).to be_successful
          bookmark.reload
          expect(bookmark).to have_attributes(bookmark_p: 'NEW_P', manifestation: manifestation, base_user: base_user)
        end
      end

      context 'when user have no bookmarks in this text' do
        it 'updates record with new bookmark value' do
          expect { subject }.to change { Bookmark.count }.by(1)
          expect(response).to be_successful
          bookmark = base_user.bookmarks.first
          expect(bookmark).to have_attributes(bookmark_p: 'NEW_P', manifestation: manifestation)
        end
      end
    end

    describe '#remove_bookmark' do
      let(:base_user) { create :base_user, session_id: session.id.private_id }
      let(:manifestation) { create(:manifestation) }
      let(:other_manifestation) { create(:manifestation) }
      let(:other_base_user) { create(:base_user, session_id: '12345') }
      let!(:bookmark) { create(:bookmark, base_user: base_user, manifestation: manifestation) }
      let!(:other_bookmark) { create(:bookmark, base_user: base_user, manifestation: other_manifestation) }
      let!(:other_base_user_bookmark) { create(:bookmark, base_user: other_base_user, manifestation: manifestation) }
      subject { post :remove_bookmark, params: { id: manifestation.id }, format: :js }

      it 'deletes bookmark of current user from given text' do
        expect { subject }.to change { Bookmark.count }.by(-1)
        expect(response).to be_successful
        expect { bookmark.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe '#like' do
      let(:user) { create(:user) }
      let(:manifestation) { create(:manifestation) }
      subject { post :like, params: { id: manifestation.id } }

      context 'when user is not logged in' do
        it 'returns ok status' do
          expect(subject).to be_successful
        end

        it 'does not add user to likers' do
          expect { subject }.not_to change { manifestation.likers.count }
        end
      end

      context 'when user is logged in' do
        before do
          session[:user_id] = user.id
        end

        it 'returns ok status' do
          expect(subject).to be_successful
        end

        it 'adds user to likers' do
          expect { subject }.to change { manifestation.likers.count }.by(1)
        end

        context 'when user already liked the manifestation' do
          before do
            manifestation.likers << user
          end

          it 'does not add user to likers again' do
            expect { subject }.not_to change { manifestation.likers.count }
          end
        end
      end
    end

    describe '#unlike' do
      let(:user) { create(:user) }
      let(:manifestation) { create(:manifestation) }
      subject { post :unlike, params: { id: manifestation.id } }

      context 'when user is not logged in' do
        it 'returns ok status' do
          expect(subject).to be_successful
        end
      end

      context 'when user is logged in' do
        before do
          session[:user_id] = user.id
        end

        it 'returns ok status' do
          expect(subject).to be_successful
        end

        context 'when user has liked the manifestation' do
          before do
            manifestation.likers << user
          end

          it 'removes user from likers' do
            expect { subject }.to change { manifestation.likers.count }.by(-1)
          end
        end

        context 'when user has not liked the manifestation' do
          it 'does not change likers count' do
            expect { subject }.not_to change { manifestation.likers.count }
          end
        end
      end
    end

    describe '#chomp_period' do
      subject(:request) { post :chomp_period, params: { id: manifestation.id } }

      context 'when title ends with dot' do
        let(:title) { 'Trailing dot.'}

        it 'removes trailing dot' do
          expect(request).to be_successful
          manifestation.reload
          expect(manifestation.title).to eq 'Trailing dot'
        end
      end

      context 'when title does not ends with dot' do
        let(:title) { 'No trailing dot'}

        it 'does not changes title' do
          expect(request).to be_successful
          manifestation.reload
          expect(manifestation.title).to eq 'No trailing dot'
        end
      end
    end

    describe '#add_aboutness' do
      include_context 'when editor logged in'

      let(:user) { create(:user, :edit_catalog) }

      before do
        session[:user_id] = user.id

        create(:aboutness, aboutable: create(:authority), work_id: manifestation.expression.work.id)
        create(:aboutness, aboutable: create(:manifestation).expression.work, work_id: manifestation.expression.work.id)
      end

      subject { get :add_aboutnesses, params: { id: manifestation.id } }

      it { is_expected.to be_successful }
    end

    describe '#workshow' do
      subject { get :workshow, params: { id: manifestation.expression.work.id} }

      it { is_expected.to redirect_to manifestation_path(manifestation) }
    end
  end
end
