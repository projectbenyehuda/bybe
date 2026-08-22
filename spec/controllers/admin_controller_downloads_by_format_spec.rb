# frozen_string_literal: true

require 'rails_helper'

describe AdminController do
  render_views

  let(:editor) { create(:user, editor: true) }
  let(:manifestation) { create(:manifestation) }
  let(:collection) { create(:collection) }

  describe '#downloads_by_format' do
    context 'when user is not an editor' do
      before { session[:user_id] = create(:user, editor: false).id }

      it 'redirects to home page' do
        get :downloads_by_format

        expect(response).to redirect_to('/')
      end
    end

    context 'when user is an editor' do
      before { session[:user_id] = editor.id }

      it 'defaults to the last year when no dates are given' do
        get :downloads_by_format

        expect(response).to have_http_status(:ok)
        expect(assigns(:from)).to eq 1.year.ago.to_date
        expect(assigns(:to)).to eq Date.current
      end

      it 'falls back to the defaults when given unparseable dates' do
        get :downloads_by_format, params: { from: 'not-a-date', to: '???' }

        expect(response).to have_http_status(:ok)
        expect(assigns(:from)).to eq 1.year.ago.to_date
        expect(assigns(:to)).to eq Date.current
      end

      it 'reports no results when nothing was downloaded' do
        get :downloads_by_format

        expect(assigns(:grand_total)).to eq 0
        expect(response.body).to include(I18n.t(:no_results))
      end

      it 'aggregates downloads per format and item type' do
        create_list(:ahoy_event, 3, :with_item, name: 'download', item: manifestation, doctype: 'epub',
                                                time: 2.days.ago)
        create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'pdf', time: 2.days.ago)
        create_list(:ahoy_event, 2, :with_item, name: 'download', item: collection, doctype: 'epub', time: 2.days.ago)

        get :downloads_by_format

        expect(assigns(:grand_total)).to eq 6
        expect(assigns(:formats)).to eq %w(epub pdf)
        expect(assigns(:item_types)).to eq %w(Collection Manifestation)
        expect(assigns(:format_totals)).to eq('epub' => 5, 'pdf' => 1)
        expect(response.body).to include('EPUB', 'PDF')
      end

      it 'honours the requested date range' do
        create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'docx', time: 2.days.ago)
        create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'docx', time: 40.days.ago)

        get :downloads_by_format, params: { from: 7.days.ago.to_date.to_s, to: Date.current.to_s }

        expect(assigns(:grand_total)).to eq 1
      end

      it 'includes downloads recorded today, at the end of the range' do
        create(:ahoy_event, :with_item, name: 'download', item: manifestation, doctype: 'txt', time: Time.current)

        get :downloads_by_format, params: { from: 7.days.ago.to_date.to_s, to: Date.current.to_s }

        expect(assigns(:grand_total)).to eq 1
      end

      it 'labels downloads that predate format tracking as unknown' do
        create(:ahoy_event, :with_item, name: 'download', item: manifestation, time: 2.days.ago)

        get :downloads_by_format

        expect(assigns(:formats)).to eq [nil]
        expect(response.body).to include(I18n.t(:unknown))
      end
    end
  end
end
