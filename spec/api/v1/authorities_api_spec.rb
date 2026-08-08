# frozen_string_literal: true

require 'rails_helper'

describe V1::AuthoritiesApi do
  include_context 'API Spec Helpers'

  describe 'GET api/v1/people/{id}' do
    subject(:call) { get path }

    let(:detail) { 'metadata' }
    let(:authority_id) { 100_001 }
    let(:path) { "/api/v1/authorities/#{authority_id}?key=#{key}&author_detail=#{detail}" }

    include_context 'API Key Check'

    context 'when wrong id provided' do
      it 'fails with Not Found status' do
        expect(call).to eq 404
        expect(error_message).to eq "Couldn't find Authority with 'id'=100001"
      end
    end

    context 'when correct id provided' do
      let!(:original_manifestation) { create(:manifestation, author: authority) }
      let!(:translated_manifestation) { create(:manifestation, translator: authority, orig_lang: 'ru') }
      let!(:edited_manifestation) { create(:manifestation, editor: authority) }
      let!(:illustrated_manifestation) { create(:manifestation, illustrator: authority) }
      let!(:manifestation_about) do
        m = create(:manifestation)
        create(:aboutness, aboutable: authority, work: m.expression.work)
        m
      end
      let(:authority) { create(:authority) }
      let(:authority_id) { authority.id }

      context 'when no details param provided' do
        let(:path) { "/api/v1/authorities/#{authority_id}?key=#{key}" }

        it 'returns personal metadata' do
          expect(call).to eq 200
          validate_authority(json_response, authority, 'metadata')
        end
      end

      # 'anonymous' and 'various authors' have no page of their own, so there is no URL for API
      # consumers to link through to.
      context 'when the authority is pageless' do
        let(:authority) { create(:authority, pageless: true) }
        let(:path) { "/api/v1/authorities/#{authority_id}?key=#{key}" }

        it 'returns a null url but the rest of the metadata as usual' do
          expect(call).to eq 200
          expect(json_response).to have_key('url')
          expect(json_response['url']).to be_nil
          expect(json_response['metadata']['name']).to eq authority.name
        end
      end

      context 'when metadata details requested' do
        let(:detail) { 'metadata' }

        it 'returns personal metadata' do
          expect(call).to eq 200
          validate_authority(json_response, authority, 'metadata')
          expect(json_response).not_to have_key('texts')
          expect(json_response).not_to have_key('enrichment')
        end

        context 'when corporate_body' do
          let(:authority) { create(:authority, :corporate_body) }

          it 'returns corporate metadata' do
            expect(call).to eq 200
            validate_authority(json_response, authority, 'metadata')
            expect(json_response).not_to have_key('texts')
            expect(json_response).not_to have_key('enrichment')
          end
        end
      end

      context 'when texts details requested' do
        let(:detail) { 'texts' }

        it 'returns a list of IDs of the works this person was involved in, with their role in each' do
          expect(call).to eq 200
          validate_authority(json_response, authority, 'texts')
          texts = json_response['texts']
          expect(texts['author']).to eq([original_manifestation.id])
          expect(texts['editor']).to eq([edited_manifestation.id])
          expect(texts['illustrator']).to eq([illustrated_manifestation.id])
          expect(texts['translator']).to eq([translated_manifestation.id])
          expect(json_response['enrichment']).to be_nil
        end
      end

      context 'when enriched details requested' do
        let(:detail) { 'enriched' }

        it 'returns personal metadata plus texts he was involved into, plus texts about this person (backlinks)' do
          expect(call).to eq 200
          validate_authority(json_response, authority, 'enriched')
          texts = json_response['texts']
          expect(texts['author']).to eq([original_manifestation.id])
          expect(texts['editor']).to eq([edited_manifestation.id])
          expect(texts['illustrator']).to eq([illustrated_manifestation.id])
          expect(texts['translator']).to eq([translated_manifestation.id])
          expect(json_response['enrichment']['texts_about']).to eq([manifestation_about.id])
        end
      end
    end
  end

  private

  def validate_person(metadata, person)
    if person.nil?
      expect(metadata).not_to have_key('person')
    else
      person_data = metadata['person']
      expect(person_data['birth_year']).to eq(person.birth_year)
      expect(person_data['death_year']).to eq(person.death_year)
      expect(person_data['gender']).to eq(person.gender)
      expect(person_data['period']).to eq(person.period)
    end
  end

  def validate_corporate_body(metadata, corporate_body)
    if corporate_body.nil?
      expect(metadata).not_to have_key('corporate_body')
    else
      corporate_data = metadata['corporate_body']
      expect(corporate_data['location']).to eq(corporate_body.location)
      expect(corporate_data['inception_year']).to eq(corporate_body.inception_year)
      expect(corporate_data['dissolution_year']).to eq(corporate_body.dissolution_year)
    end
  end

  def validate_authority(json, authority, detail)
    expect(json['id']).to eq authority.id
    expect(json['url']).to eq Rails.application.routes.url_helpers.authority_url(authority)
    metadata = json['metadata']
    expect(metadata).not_to be_nil
    expect(metadata['name']).to eq(authority.name)
    expect(metadata['sort_name']).to eq(authority.sort_name)

    validate_person(metadata, authority.person)
    validate_corporate_body(metadata, authority.corporate_body)

    expect(metadata['intellectual_property']).to eq(authority.intellectual_property)

    if %w(texts enriched).include?(detail)
      texts = json['texts']
      InvolvedAuthority.roles.each_key do |role|
        expect(texts).to have_key(role)
      end
    else
      expect(metadata).not_to have_key('texts')
    end

    expect(metadata['other_designations']).to eq(authority.other_designation)
    expect(metadata['bio_snippet']).to eq(authority.wikipedia_snippet)
    expect(metadata['languages']).to eq(authority.all_languages)
    expect(metadata['genres']).to eq(authority.all_genres)
    expect(metadata['impressions_count']).to eq(authority.impressions_count)

    if detail == 'enriched'
      enrichment = json['enrichment']
      expect(enrichment).not_to be_nil
      expect(enrichment['texts_about']).not_to be_nil
    else
      expect(json).not_to have_key('enrichment')
    end
  end
end
