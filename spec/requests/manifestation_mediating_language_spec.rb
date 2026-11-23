# frozen_string_literal: true

require 'rails_helper'

# A translation made via an intermediate language (e.g. the Kalevala, translated from Russian rather than Finnish)
# shows that mediating language right below the source language in the metadata section.
describe 'Manifestation#read mediating language', type: :request do
  let!(:text) do
    Chewy.strategy(:atomic) { create(:manifestation, orig_lang: 'fi', language: 'he', status: :published) }
  end

  after { Chewy.massacre }

  def metadata_rows
    get manifestation_path(text)
    Nokogiri::HTML(response.body).css('.metadata')
  end

  context 'when the expression has a mediating language' do
    before { text.expression.update_column(:mediating_language, 'ru') }

    it 'shows it right after the source language, in the smaller-font row' do
      rows = metadata_rows
      orig_index = rows.index { |row| row.text.include?(I18n.t(:orig_lang)) }
      mediating_row = rows[orig_index + 1]

      expect(mediating_row['class']).to include('metadata-mediating-language')
      expect(mediating_row.text).to include(I18n.t(:mediating_language), I18n.t(:russian))
    end
  end

  context 'when the expression has no mediating language' do
    it 'does not show the mediating language label anywhere on the page' do
      expect(text.expression.mediating_language).to be_nil
      get manifestation_path(text)

      expect(response.body).not_to include(I18n.t(:mediating_language))
      expect(Nokogiri::HTML(response.body).css('.metadata-mediating-language')).to be_empty
      # the source language row is still there, so the absence above is meaningful
      expect(response.body).to include(I18n.t(:orig_lang))
    end
  end
end
