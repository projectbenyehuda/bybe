# frozen_string_literal: true

require 'rails_helper'

describe ManifestationController do
  describe '#kwic_context' do
    let(:manifestation) do
      create(
        :manifestation,
        title: 'Test Work',
        markdown: "First paragraph.\n\nSecond paragraph with keyword.\n\nThird paragraph."
      )
    end

    it 'returns extended context for a paragraph' do
      get :kwic_context, params: { id: manifestation.id, paragraph: 2 }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['prev']).to be_present
      expect(json['current']).to be_present
      expect(json['next']).to be_present
    end

    it 'handles first paragraph (no previous)' do
      get :kwic_context, params: { id: manifestation.id, paragraph: 1 }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['prev']).to be_nil
      expect(json['current']).to be_present
      expect(json['next']).to be_present
    end

    it 'handles last paragraph (no next)' do
      get :kwic_context, params: { id: manifestation.id, paragraph: 3 }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['prev']).to be_present
      expect(json['current']).to be_present
      expect(json['next']).to be_nil
    end
  end
end
