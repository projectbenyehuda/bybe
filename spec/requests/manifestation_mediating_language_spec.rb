# frozen_string_literal: true

require 'rails_helper'

# A translation made via an intermediate language (e.g. the Kalevala, translated from Russian rather than Finnish)
# names the mediating language after the translator, since that is what the Hebrew text was translated from.
# The work's original language stays in the source language row of the metadata section.
describe 'Manifestation#read mediating language', type: :request do
  include BybeUtils

  let!(:text) do
    Chewy.strategy(:atomic) { create(:manifestation, orig_lang: 'fi', language: 'he', status: :published) }
  end

  let(:page) do
    get manifestation_path(text)
    Nokogiri::HTML(response.body)
  end
  let(:translator_line) { page.at_css('.headline-2-v02').text }
  let(:source_language_row) { page.css('.metadata').find { |row| row.text.include?(I18n.t(:orig_lang)) } }

  after { Chewy.massacre }

  context 'when the expression has a mediating language' do
    before { text.expression.update_column(:mediating_language, 'ru') }

    it 'names the mediating language after the translator' do
      expect(translator_line).to include("(#{orig_lang_label('ru')})")
      expect(translator_line).not_to include(orig_lang_label('fi'))
    end

    it "keeps the work's original language in the source language row" do
      expect(source_language_row.text).to include(I18n.t(:finnish))
    end

    it 'does not add a separate mediating language row' do
      expect(page.text).not_to include(I18n.t(:mediating_language))
    end
  end

  context 'when the expression has no mediating language' do
    it "names the work's original language after the translator, as before" do
      expect(translator_line).to include("(#{orig_lang_label('fi')})")
    end

    it 'still shows the source language row' do
      expect(source_language_row.text).to include(I18n.t(:finnish))
    end

    it 'does not mention a mediating language anywhere on the page' do
      expect(page.text).not_to include(I18n.t(:mediating_language))
    end
  end
end
