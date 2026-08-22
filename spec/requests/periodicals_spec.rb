# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Periodicals', type: :request do
  describe 'GET /' do
    it 'returns http success' do
      get '/periodicals'
      expect(response).to have_http_status(:success)
    end

    context 'with new periodical publications' do
      let(:author) { create(:authority) }
      let(:periodical_issue) { create(:collection, collection_type: 'periodical_issue') }
      let!(:periodical_work) do
        work = create(:manifestation, author: author, orig_lang: 'he', created_at: 2.weeks.ago)
        create(:collection_item, collection: periodical_issue, item: work)
        work
      end

      it 'populates @periodicals_whatsnew with recent periodical publications' do
        get '/periodicals'
        expect(assigns(:periodicals_whatsnew)).to be_present
        expect(assigns(:periodicals_whatsnew).keys).to include(author)
      end

      it 'renders the whatsnew section in the view' do
        get '/periodicals'
        expect(response.body).to include('מה חדש בכתבי עת?')
      end
    end

    context 'without new periodical publications' do
      before do
        # Clear cache to ensure fresh data
        Rails.cache.delete('periodicals_whatsnew')
      end

      it 'displays the empty state message when there are no new publications' do
        get '/periodicals'
        # The view should still render successfully
        expect(response).to have_http_status(:success)
      end
    end

    context 'with more than 3 authors' do
      let(:periodical_issue) { create(:collection, collection_type: 'periodical_issue') }
      let!(:authors_and_works) do
        # Create 5 authors with works in periodicals (more than the 3-card limit)
        5.times.map do
          author = create(:authority)
          work = create(:manifestation, author: author, orig_lang: 'he', created_at: 2.weeks.ago)
          create(:collection_item, collection: periodical_issue, item: work)
          [author, work]
        end
      end

      before do
        # Clear cache to ensure fresh data
        Rails.cache.delete('periodicals_whatsnew')
      end

      it 'includes the see-all link when there are more than 3 authors' do
        get '/periodicals'
        expect(response.body).to include('link-to-all-v02')
        expect(response.body).to include(I18n.t(:see_all_new_periodicals))
      end

      it 'includes a modal with all new works' do
        get '/periodicals'
        expect(response.body).to include('periodicalsWhatsnewDlg')
        expect(response.body).to include(I18n.t(:new_works_in_periodicals))
      end

      it 'includes all author works in the page' do
        get '/periodicals'
        # All works should be present in the page (in the modal)
        authors_and_works.each do |author, work|
          expect(response.body).to include(work.expression.title)
        end
      end
    end
  end

  # Regression: works flagged non-primary (e.g. an issue's editorial column) are parts of a larger
  # text, not standalone works, and must not surface in the periodicals landing page's work lists.
  describe 'suppression of non-primary works in the newest/popular lists' do
    let!(:periodical_issue) { create(:collection, collection_type: 'periodical_issue') }
    let!(:primary_work) do
      create(:manifestation, title: 'Primary Periodical Work', impressions_count: 5, collections: [periodical_issue])
    end
    let!(:non_primary_work) do
      create(:manifestation, title: 'Editorial Column', primary: false, impressions_count: 99,
                             collections: [periodical_issue])
    end

    before do
      Chewy.massacre
      import_and_await(ManifestationsIndex, [primary_work, non_primary_work])
      get '/periodicals'
    end

    after do
      Chewy.massacre
    end

    it 'excludes non-primary works from @newest_works' do
      expect(assigns(:newest_works).map { |w| w.id.to_i }).to contain_exactly(primary_work.id)
    end

    it 'excludes non-primary works from @popular_works' do
      expect(assigns(:popular_works).map { |w| w.id.to_i }).to contain_exactly(primary_work.id)
    end
  end

  describe 'GET /show' do
    it 'returns http success' do
      get '/periodicals/show'
      expect(response).to have_http_status(:success)
    end
  end

  describe '@periodical_first_covers assignment' do
    let!(:periodical) { create(:collection, collection_type: 'periodical', title: 'Test Periodical Title') }
    let!(:issue_no_cover) { create(:collection, collection_type: 'periodical_issue') }
    let!(:issue_with_cover) do
      c = create(:collection, collection_type: 'periodical_issue')
      c.cover_image.attach(
        io: StringIO.new(Rails.root.join('spec/fixtures/files/test_image.jpg').binread),
        filename: 'cover.jpg',
        content_type: 'image/jpeg'
      )
      c
    end

    before do
      create(:collection_item, collection: periodical, item: issue_no_cover, seqno: 1)
      create(:collection_item, collection: periodical, item: issue_with_cover, seqno: 2)
      # the index only lists periodicals with publicly accessible works
      create(:collection_item, collection: issue_no_cover, item: create(:manifestation, status: :published), seqno: 1)
    end

    it 'assigns @periodical_first_covers as a hash' do
      get '/periodicals'
      expect(assigns(:periodical_first_covers)).to be_a(Hash)
    end

    it 'maps the periodical to the first issue with a cover image' do
      get '/periodicals'
      expect(assigns(:periodical_first_covers)[periodical.id]).to eq(issue_with_cover)
    end

    it 'renders the cover image tile for periodicals with a covered issue' do
      get '/periodicals'
      expect(response.body).to include('periodical-with-cover')
      expect(response.body).to include('periodical-cover-img')
      expect(response.body).to include(periodical.title)
    end
  end

  describe '@periodical_first_covers with no covered issues' do
    let!(:periodical) { create(:collection, collection_type: 'periodical') }
    let!(:issue_no_cover) { create(:collection, collection_type: 'periodical_issue') }

    before do
      create(:collection_item, collection: periodical, item: issue_no_cover, seqno: 1)
      # the index only lists periodicals with publicly accessible works
      create(:collection_item, collection: issue_no_cover, item: create(:manifestation, status: :published), seqno: 1)
    end

    it 'maps the periodical to nil when no issues have a cover' do
      get '/periodicals'
      expect(assigns(:periodical_first_covers)[periodical.id]).to be_nil
    end

    it 'does not render the cover image tile' do
      get '/periodicals'
      expect(response.body).not_to include('periodical-with-cover')
    end
  end

  describe 'suppression of zero-issue periodicals' do
    let!(:periodical_with_issue) do
      create(:collection, collection_type: 'periodical', title: 'Has Issues Periodical')
    end
    let!(:periodical_no_issues) do
      create(:collection, collection_type: 'periodical', title: 'No Issues Periodical')
    end
    let!(:issue) { create(:collection, collection_type: 'periodical_issue') }

    before do
      create(:collection_item, collection: periodical_with_issue, item: issue, seqno: 1)
      # the index only lists periodicals with publicly accessible works
      create(:collection_item, collection: issue, item: create(:manifestation, status: :published), seqno: 1)
    end

    it 'does not include zero-issue periodicals in @periodicals' do
      get '/periodicals'
      expect(assigns(:periodicals)).to include(periodical_with_issue)
      expect(assigns(:periodicals)).not_to include(periodical_no_issues)
    end

    it 'does not render the zero-issue periodical title on the page' do
      get '/periodicals'
      expect(response.body).not_to include('No Issues Periodical')
    end

    it 'sets @periodicals_count to only count periodicals with issues' do
      get '/periodicals'
      expect(assigns(:periodicals_count)).to eq(assigns(:periodicals).size)
    end
  end

  describe 'suppression of periodicals without publicly accessible works' do
    let!(:periodical_with_published) do
      create(:collection, collection_type: 'periodical', title: 'Published Works Periodical')
    end
    let!(:periodical_unpublished_only) do
      create(:collection, collection_type: 'periodical', title: 'Unpublished Only Periodical')
    end
    let!(:periodical_empty_issues) do
      create(:collection, collection_type: 'periodical', title: 'Empty Issues Periodical')
    end

    before do
      %w(published unpublished empty).zip(
        [periodical_with_published, periodical_unpublished_only, periodical_empty_issues]
      ).each do |kind, periodical|
        issue = create(:collection, collection_type: 'periodical_issue')
        create(:collection_item, collection: periodical, item: issue, seqno: 1)
        next if kind == 'empty'

        status = kind == 'published' ? :published : :unpublished
        create(:collection_item, collection: issue, item: create(:manifestation, status: status), seqno: 1)
      end
    end

    it 'lists only the periodical holding a published work' do
      get '/periodicals'
      expect(assigns(:periodicals)).to include(periodical_with_published)
      expect(assigns(:periodicals)).not_to include(periodical_unpublished_only, periodical_empty_issues)
    end

    it 'does not render the suppressed periodicals on the page' do
      get '/periodicals'
      expect(response.body).to include('Published Works Periodical')
      expect(response.body).not_to include('Unpublished Only Periodical')
      expect(response.body).not_to include('Empty Issues Periodical')
    end

    it 'counts only the listed periodicals' do
      get '/periodicals'
      expect(assigns(:periodicals_count)).to eq(assigns(:periodicals).size)
    end

    context 'when an editor is logged in' do
      before { login_as(create(:user, editor: true)) }

      it 'lists the periodicals lacking publicly accessible works too' do
        get '/periodicals'
        expect(assigns(:periodicals)).to include(
          periodical_with_published, periodical_unpublished_only, periodical_empty_issues
        )
      end

      it 'renders the otherwise-suppressed periodicals on the page' do
        get '/periodicals'
        expect(response.body).to include('Unpublished Only Periodical')
        expect(response.body).to include('Empty Issues Periodical')
      end
    end

    context 'when a logged-in non-editor is browsing' do
      before { login_as(create(:user)) }

      it 'still suppresses the periodicals lacking publicly accessible works' do
        get '/periodicals'
        expect(assigns(:periodicals)).to include(periodical_with_published)
        expect(assigns(:periodicals)).not_to include(periodical_unpublished_only, periodical_empty_issues)
      end
    end

    context 'when the published work sits in a sub-collection of the issue' do
      let!(:periodical_nested) do
        create(:collection, collection_type: 'periodical', title: 'Nested Works Periodical')
      end

      before do
        issue = create(:collection, collection_type: 'periodical_issue')
        series = create(:collection, collection_type: 'series')
        create(:collection_item, collection: periodical_nested, item: issue, seqno: 1)
        create(:collection_item, collection: issue, item: series, seqno: 1)
        create(:collection_item, collection: series, item: create(:manifestation, status: :published), seqno: 1)
      end

      it 'still lists the periodical' do
        get '/periodicals'
        expect(assigns(:periodicals)).to include(periodical_nested)
      end
    end
  end
end
