# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::MassUpdates', type: :request do
  before { login_as_batch_editor }

  let(:manifestation) { create(:manifestation, title: 'Test Manifestation') }
  let(:collection)    { create(:collection, title: 'Test Collection', collection_type: :volume) }

  # ---------------------------------------------------------------------------
  # POST /admin/mass_update  (create)
  # ---------------------------------------------------------------------------
  describe 'POST /admin/mass_update' do
    it 'returns 422 with error key when records list is empty' do
      post admin_mass_update_path,
           params: { records: [], changes: [{ kind: 'field_update' }] },
           as: :json
      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body['error']).to eq(I18n.t('admin.mass_update.errors.no_records'))
    end

    it 'returns 422 with error key when changes list is empty' do
      post admin_mass_update_path,
           params: { records: [{ type: 'Manifestation', id: manifestation.id }], changes: [] },
           as: :json
      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body['error']).to eq(I18n.t('admin.mass_update.errors.no_changes'))
    end

    it 'returns results JSON for a valid request' do
      post admin_mass_update_path,
           params: {
             records: [{ type: 'Manifestation', id: manifestation.id }],
             changes: [{ kind: 'field_update', record_type: 'manifestation',
                         field: 'title', value: 'Updated Via API' }]
           },
           as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['results']).to be_an(Array)
      expect(body['results'].first['results'].first['ok']).to be true
      expect(manifestation.reload.title).to eq('Updated Via API')
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/mass_update/collection_contents
  # ---------------------------------------------------------------------------
  describe 'GET /admin/mass_update/collection_contents' do
    let!(:sub_manifestation) { create(:manifestation, title: 'Sub Work') }
    let!(:_item) do
      create(:collection_item, collection: collection, item: sub_manifestation,
                               seqno: 1, item_type: 'Manifestation')
    end

    it 'returns a flat item list with correct type and depth' do
      get admin_mass_update_collection_contents_path, params: { collection_id: collection.id }
      expect(response).to have_http_status(:ok)
      items = response.parsed_body['items']
      expect(items).to be_an(Array)
      expect(items.length).to eq(1)
      expect(items.first['type']).to eq('Manifestation')
      expect(items.first['id']).to eq(sub_manifestation.id)
      expect(items.first['depth']).to eq(0)
    end

    it 'returns nested items with incremented depth for sub-collections' do
      sub_collection = create(:collection, title: 'Sub Collection', collection_type: :volume)
      sub_sub_manifestation = create(:manifestation, title: 'Deep Work')
      create(:collection_item, collection: collection, item: sub_collection,
                               seqno: 2, item_type: 'Collection')
      create(:collection_item, collection: sub_collection, item: sub_sub_manifestation,
                               seqno: 1, item_type: 'Manifestation')

      get admin_mass_update_collection_contents_path, params: { collection_id: collection.id }
      items = response.parsed_body['items']
      # Should have: sub_manifestation (depth 0), sub_collection (depth 0), sub_sub_manifestation (depth 1)
      depths = items.to_h { |i| [i['title'], i['depth']] }
      expect(depths['Sub Work']).to eq(0)
      expect(depths['Sub Collection']).to eq(0)
      expect(depths['Deep Work']).to eq(1)
    end

    it 'returns items ordered by seqno' do
      second = create(:manifestation, title: 'Second Work')
      create(:collection_item, collection: collection, item: second, seqno: 2, item_type: 'Manifestation')

      get admin_mass_update_collection_contents_path, params: { collection_id: collection.id }
      items = response.parsed_body['items']
      expect(items.map { |i| i['title'] }).to eq(['Sub Work', 'Second Work']) # rubocop:disable Rails/Pluck
    end

    it 'returns 404 for an unknown collection_id' do
      get admin_mass_update_collection_contents_path, params: { collection_id: 0 }
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/mass_update/authority_manifestations
  # ---------------------------------------------------------------------------
  describe 'GET /admin/mass_update/authority_manifestations' do
    let(:authority) { create(:authority) }

    it 'returns manifestations whose Work involves the authority' do
      work = manifestation.expression.work
      InvolvedAuthority.create!(item: work, authority: authority, role: :editor)

      get admin_mass_update_authority_manifestations_path, params: { authority_id: authority.id }
      expect(response).to have_http_status(:ok)
      returned_ids = response.parsed_body['manifestations'].map { |m| m['id'] } # rubocop:disable Rails/Pluck
      expect(returned_ids).to include(manifestation.id)
    end

    it 'returns manifestations whose Expression involves the authority' do
      expression = manifestation.expression
      InvolvedAuthority.create!(item: expression, authority: authority, role: :translator)

      get admin_mass_update_authority_manifestations_path, params: { authority_id: authority.id }
      returned_ids = response.parsed_body['manifestations'].map { |m| m['id'] } # rubocop:disable Rails/Pluck
      expect(returned_ids).to include(manifestation.id)
    end

    it 'returns 404 for an unknown authority_id' do
      get admin_mass_update_authority_manifestations_path, params: { authority_id: 0 }
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/mass_update/record_info
  # ---------------------------------------------------------------------------
  describe 'GET /admin/mass_update/record_info' do
    it 'returns id and title for a Manifestation' do
      get admin_mass_update_record_info_path, params: { type: 'Manifestation', id: manifestation.id }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(manifestation.id)
      expect(body['title']).to eq(manifestation.title)
      expect(body['type']).to eq('Manifestation')
    end

    it 'returns id and title for a Collection' do
      col = create(:collection, title: 'My Collection', collection_type: :volume)
      get admin_mass_update_record_info_path, params: { type: 'Collection', id: col.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['title']).to eq('My Collection')
    end

    it 'returns 404 for unknown id' do
      get admin_mass_update_record_info_path, params: { type: 'Manifestation', id: 0 }
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization: batch_editing bit required
  # ---------------------------------------------------------------------------
  describe 'authorization' do
    it 'redirects an editor without batch_editing bit' do
      user = create(:user, editor: true)
      # has edit_catalog but NOT batch_editing
      ListItem.create!(listkey: 'edit_catalog', item: user)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      # override the global stub so the real require_editor runs
      allow_any_instance_of(ApplicationController).to receive(:require_editor).and_call_original

      get admin_mass_update_path
      expect(response).to redirect_to('/')
    end
  end
end
