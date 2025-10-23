require 'rails_helper'

describe AuthorsController do
  describe '#browse' do
    subject(:call) { get :browse, params: { sort_by: sort_by }.compact }

    let(:sort_by) { nil }

    let(:corporate_body) { create(:authority, :corporate_body) }

    before do
      clean_tables
      Chewy.strategy(:atomic) do
        create_list(:manifestation, 5)
        create(:manifestation, author: corporate_body)
      end
    end

    it { is_expected.to be_successful }

    describe 'sorting' do
      AuthorsController::SORTING_PROPERTIES.each_key do |sort|
        %w(asc desc).each do |dir|
          context "when by #{sort} in #{dir} order" do
            let(:sort_by) { "#{sort}_#{dir}" }

            it { is_expected.to be_successful }
          end
        end
      end
    end
  end

  describe '#all' do
    subject { get :all }

    it { is_expected.to redirect_to authors_path }
  end

  describe '#get_random_author' do
    before do
      create_list(:manifestation, 5)
    end

    context 'when genre is not provided' do
      subject { get :get_random_author, params: {} }

      it { is_expected.to be_successful }
    end

    context 'when genre provided' do
      subject { get :get_random_author, params: { genre: genre } }

      let(:genre) { Work.first.genre }

      it { is_expected.to be_successful }
    end
  end

  describe 'member actions' do
    let!(:author) { create(:authority) }

    describe '#toc' do
      subject(:request) { get :toc, params: { id: author.id } }

      let(:toc) { create(:toc) }

      before do
        create_list(:manifestation, 5, author: author, created_at: 3.days.ago)
        author.toc = toc
        author.save!
      end

      it 'renders successfully' do
        expect(request).to be_successful
      end

      context 'when fresh work exists' do
        before do
          create(:manifestation, author: author, created_at: 6.hours.ago)
        end

        it 'renders successfully' do
          expect(request).to be_successful
        end
      end
    end

    describe '#new_toc' do
      subject { get :new_toc, params: { id: authority.id } }

      include_context 'when authority has several collections'

      it { is_expected.to be_successful }
    end

    describe '#whatsnew_popup' do
      subject { get :whatsnew_popup, params: { id: author.id } }

      let!(:manifestation) { create(:manifestation, created_at: created_at, author: author) }

      context 'when there is a new work in last month' do
        let(:created_at) { 20.days.ago }

        it { is_expected.to be_successful }
      end

      context 'when there is no new works in last month' do
        let(:created_at) { 35.days.ago }

        it { is_expected.to be_successful }
      end
    end

    describe '#latest_popup' do
      subject { get :latest_popup, params: { id: author.id } }

      context 'when author has works' do
        before do
          create_list(:manifestation, 25, author: author)
        end

        it { is_expected.to be_successful }
      end

      context 'when there are no works' do
        it { is_expected.to be_successful }
      end
    end

    describe '#print' do
      subject { get :print, params: { id: author.id } }

      before do
        create(:manifestation, author: author)
        create(:manifestation, orig_lang: 'de', translator: author)
      end

      it { is_expected.to be_successful }
    end
  end

  describe 'Editor actions' do
    include_context 'when editor logged in', :edit_people

    describe '#list' do
      subject { get :list }

      before do
        create_list(:authority, 5)     # authors without works
        create_list(:manifestation, 5) # this will create authors with works
        create_list(:publication, 2)   # will create authors with publications
      end

      it { is_expected.to be_successful }
    end

    describe '#new' do
      subject(:call) { get :new, params: { type: type } }

      context 'when person' do
        let(:type) { 'person' }

        it 'succeed' do
          expect(call).to be_successful
          expect(assigns(:author).person).to be_present
          expect(assigns(:author).corporate_body).to be_nil
        end
      end

      context 'when corporate_body' do
        let(:type) { 'corporate_body' }

        it 'succeed' do
          expect(call).to be_successful
          expect(assigns(:author).person).to be_nil
          expect(assigns(:author).corporate_body).to be_present
        end
      end

      context 'when wrong type is specified' do
        let(:type) { 'wrong' }

        it 'raises error' do
          expect { call }.to raise_error 'Unknown type: \'wrong\''
        end
      end
    end

    describe '#create' do
      subject(:call) { post :create, params: { authority: authority_params } }

      let(:intellectual_property) { 'permission_for_selected' }
      let(:status) { 'published' }

      let(:person_attributes) { { birthdate: '1850' } }
      let(:authority_attributes) do
        {
          name: 'New name',
          intellectual_property: intellectual_property,
          status: status
        }
      end

      let(:authority_params) do
        authority_attributes.merge(person_attributes: person_attributes)
      end

      let(:created_authority) { Authority.order(id: :desc).first }

      context 'when save successful' do
        it 'creates record' do
          expect { call }.to change(Authority, :count).by(1)
                                                      .and change(Person, :count).by(1)
                                                      .and not_change(CorporateBody, :count)
          expect(created_authority).to have_attributes(authority_attributes)
          expect(created_authority.person).to have_attributes(person_attributes)

          expect(call).to redirect_to authors_show_path(id: created_authority.id)
          expect(flash.notice).to eq I18n.t(:created_successfully)
        end

        context 'when status is not set' do
          let(:status) { nil }

          context 'when intellectual_property is public_domain' do
            let(:intellectual_property) { 'public_domain' }

            it 'sets status to awaiting_first' do
              expect { call }.to change(Authority, :count).by(1)
              expect(created_authority.status).to eq 'awaiting_first'
            end
          end

          context 'when intellectual_property is not public_domain' do
            let(:intellectual_property) { 'permission_for_selected' }

            it 'sets status to unpublished' do
              expect { call }.to change(Authority, :count).by(1)
              expect(created_authority.status).to eq 'unpublished'
            end
          end
        end

        context 'when corporate_body' do
          let(:corporate_body_attributes) { { location: 'Tallin', inception: '1982' } }

          let(:authority_params) do
            authority_attributes.merge(corporate_body_attributes: corporate_body_attributes)
          end

          it 'creates record' do
            expect { call }.to change(Authority, :count).by(1)
                                                        .and change(CorporateBody, :count).by(1)
                                                        .and not_change(Person, :count)
            expect(created_authority).to have_attributes(authority_attributes)
            expect(created_authority.corporate_body).to have_attributes(corporate_body_attributes)

            expect(call).to redirect_to authors_show_path(id: created_authority.id)
            expect(flash.notice).to eq I18n.t(:created_successfully)
          end
        end
      end

      context 'when save fails' do
        let(:status) { :unpublished }
        let(:intellectual_property) { nil }

        it 're-renders new form' do
          expect { call }.not_to change(Authority, :count)
          expect(call).to render_template(:new)
          expect(call).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe 'member actions' do
      let(:period) { 'revival' }
      let(:intellectual_property) { :public_domain }
      let(:status) { 'published' }
      let(:author) do
        create(:authority, intellectual_property: intellectual_property, period: period, status: status)
      end

      describe '#show' do
        subject(:call) { get :show, params: { id: author.id } }

        before do
          create_list(:manifestation, 3, author: author)
          create(:manifestation, author: author, status: :unpublished)
          create_list(:manifestation, 6, translator: author, orig_lang: 'de')
          create_list(:manifestation, 2, translator: author, orig_lang: 'de', status: :unpublished)
          create_list(:aboutness, 3, aboutable: author)
        end

        it 'renders successfully' do
          expect(call).to be_successful
          expect(assigns(:published_works)).to eq 3
          expect(assigns(:published_xlats)).to eq 6
          expect(assigns(:total_orig_works)).to eq 4
          expect(assigns(:total_xlats)).to eq 8
        end

        context 'when non-public domain' do
          # there is a special logic in view for such case
          let(:intellectual_property) { :permission_for_selected }

          it { is_expected.to be_successful }
        end

        context 'when bibliography exists' do
          let!(:publications) { create_list(:publication, 3, authority: author) }

          it { is_expected.to be_successful }
        end

        context 'when corporate_body' do
          let(:author) { create(:authority, :corporate_body) }

          it { is_expected.to be_successful }
        end
      end

      describe '#publish' do
        subject(:call) { get :publish, params: { id: author.id, commit: commit }.compact }

        let(:status) { :unpublished }
        let(:works) { create_list(:manifestation, 3, author: author, status: :unpublished) }

        context 'when list is requested' do
          let(:commit) { nil }

          before { works }

          it 'renders page' do
            expect(call).to be_successful
            expect(call).to render_template(:publish)
            expect(assigns(:manifestations)).to eq works
          end

          context 'when corporate_body' do
            let(:author) { create(:authority, :corporate_body) }

            it { is_expected.to be_successful }
          end
        end

        context 'when publish action is requested' do
          let(:commit) { 'publish' }

          context 'when there are no works' do
            it 'sets author status to awaiting_first' do
              expect(call).to redirect_to authors_list_path
              author.reload
              expect(author.status).to eq 'awaiting_first'
              expect(flash[:success]).to eq I18n.t(:awaiting_first)
            end
          end

          context 'when there are unpublished works' do
            before { works }

            it 'sets author status to published and publish all works' do
              expect(call).to redirect_to authors_list_path
              author.reload
              expect(author.status).to eq 'published'
              works.each do |work|
                work.reload
                expect(work).to be_published
              end
              expect(flash[:success]).to eq I18n.t(:published)
            end
          end
        end
      end

      describe '#edit' do
        subject { get :edit, params: { id: author.id } }

        it { is_expected.to be_successful }

        context 'when corporate_body' do
          let(:author) { create(:authority, :corporate_body) }

          it { is_expected.to be_successful }
        end
      end

      describe '#to_manual_toc' do
        subject(:call) { get :to_manual_toc, params: { id: author.id } }

        before do
          create_list(:manifestation, 3, author: author, orig_lang: 'de')
          create_list(:manifestation, 2, orig_lang: 'ru', translator: author)

          # work with several authors and translators
          m = create(:manifestation, author: author, orig_lang: 'en')
          create(:involved_authority, item: m.expression.work, role: :author)
          create(:involved_authority, item: m.expression.work, role: :author)
          create(:involved_authority, item: m.expression, role: :translator)
          create(:involved_authority, item: m.expression, role: :translator)
        end

        context 'when there is no TOC yet' do
          it 'creates new TOC' do
            expect { call }.to change(Toc, :count).by(1)
            toc = Toc.order(id: :desc).first
            author.reload
            expect(author.toc).to eq(toc)
            expect(flash.notice).to eq I18n.t(:created_toc)
            expect(call).to redirect_to authors_edit_toc_path(id: author)
          end
        end

        context 'when author already has TOC' do
          before do
            author.toc = create(:toc)
            author.save!
          end

          it 'shows error message' do
            expect { call }.to not_change(Toc, :count)
            expect(flash[:error]).to eq I18n.t(:already_has_toc)
            expect(call).to redirect_to authors_edit_toc_path(id: author)
          end
        end
      end

      describe '#edit_toc' do
        subject(:call) { get :edit_toc, params: { id: author.id } }

        context 'when TOC does not exists yet' do
          it 'redirects to home page' do
            expect(call).to redirect_to '/'
            expect(flash['error']).to eq I18n.t('no_toc_yet')
          end
        end

        context 'when TOC exists' do
          let(:toc) { create(:toc) }

          before do
            author.toc = toc
            author.save!
          end

          it { is_expected.to be_successful }

          context 'when corporate_body' do
            let(:author) { create(:authority, :corporate_body) }

            it { is_expected.to be_successful }
          end
        end
      end

      describe '#update' do
        subject(:request) do
          put :update, params: {
            id: author.id,
            authority: authority_params
          }
        end

        let(:authority_attributes) do
          {
            name: new_name,
            intellectual_property: new_intellectual_property,
            wikidata_uri: new_wikidata_uri
          }
        end

        let(:person_attributes) do
          {
            id: author.person.id,
            period: new_period
          }
        end

        let(:authority_params) do
          authority_attributes.merge(person_attributes: person_attributes)
        end

        let(:new_name) { 'New Name' }
        let(:new_intellectual_property) { 'unknown' }
        let(:new_wikidata_uri) { 'https://wikidata.org/wiki/Q1234' }

        let(:works_period) { 'modern' } # intentionally use value different from author period
        let!(:original_work) { create(:manifestation, orig_lang: 'he', author: author, period: works_period) }
        let!(:original_foreign_work) do
          create(:manifestation, orig_lang: 'ru', language: 'he', author: author, period: works_period)
        end
        let!(:translated_work) { create(:manifestation, orig_lang: 'ru', translator: author, period: works_period) }
        let!(:translated_to_foreign_work) do
          create(:manifestation, orig_lang: 'he', language: 'ru', translator: author, period: works_period)
        end

        context 'when period attribute was changed' do
          let(:new_period) { 'ancient' }

          it 'updates author and sets period in his hebrew works and translations to hebrew' do
            expect(request).to redirect_to authors_show_path(id: author.id)
            author.reload
            expect(author).to have_attributes(authority_attributes)
            expect(author.person).to have_attributes(period: new_period)
            original_work.reload
            expect(original_work.expression.period).to eq new_period
            translated_work.reload
            expect(translated_work.expression.period).to eq new_period

            # period of original work in foreign language is not changed
            original_foreign_work.reload
            expect(original_foreign_work.expression.period).to eq works_period

            # period of translation to foreign language is not changed
            translated_to_foreign_work.reload
            expect(translated_to_foreign_work.expression.period).to eq works_period
          end
        end

        context 'when period is not changed' do
          let(:new_period) { period }

          it 'updates author but not his works' do
            expect(request).to redirect_to authors_show_path(id: author.id)
            author.reload
            expect(author).to have_attributes(authority_attributes)
            expect(author.person).to have_attributes(person_attributes)
            original_work.reload
            expect(original_work.expression.period).to eq works_period
            translated_work.reload
            expect(translated_work.expression.period).to eq works_period
            original_foreign_work.reload
            expect(original_foreign_work.expression.period).to eq works_period
            translated_to_foreign_work.reload
            expect(translated_to_foreign_work.expression.period).to eq works_period
          end
        end

        context 'when validation error occurs' do
          let(:new_wikidata_uri) { 'https://wrongsite.com/Q123' }
          let(:new_period) { period }

          it 'fails to save and re-renders edit form' do
            expect(request).to have_http_status(:unprocessable_content)
            expect(response).to render_template :edit
          end
        end

        context 'when corporate_body' do
          let(:author) { create(:authority, :corporate_body) }

          let(:corporate_body_attributes) do
            {
              id: author.corporate_body.id,
              location: 'NEW LOCATION'
            }
          end

          let(:authority_params) do
            authority_attributes.merge(corporate_body_attributes: corporate_body_attributes)
          end

          it 'updates authority and corporate_body' do
            expect(request).to redirect_to authors_show_path(id: author.id)
            author.reload
            expect(author).to have_attributes(authority_attributes)
            expect(author.corporate_body).to have_attributes(corporate_body_attributes)
          end
        end
      end

      describe '#destroy' do
        subject(:call) { delete :destroy, params: { id: author.id } }

        before do
          create_list(:manifestation, 3, author: author)
          create_list(:manifestation, 2, orig_lang: 'ru', translator: author)
        end

        it 'removes authority but keeps texts it was involved into' do
          expect { call }.to change(Authority, :count).by(-1)
                                                      .and change(InvolvedAuthority, :count).by(-5)
                                                      .and not_change(Manifestation, :count)
          expect(call).to redirect_to authors_list_path
        end
      end

      describe '#add_link' do
        subject(:call) { post :add_link, params: { id: author.id, link_description: desc, add_url: url }, format: :js }

        context 'when required params are missing' do
          let(:desc) { nil }
          let(:url) { nil }

          it { is_expected.to have_http_status(:bad_request) }
        end

        context 'when all required params are present' do
          let(:desc) { 'description' }
          let(:url) { 'https://test.com' }

          let(:created_link) { ExternalLink.order(id: :desc).first }

          it 'creates link' do
            expect { call }.to change(ExternalLink, :count).by(1)
            expect(created_link).to have_attributes(
              description: desc,
              url: url,
              status: 'approved',
              linkable: author
            )
          end
        end
      end
    end
  end
end
