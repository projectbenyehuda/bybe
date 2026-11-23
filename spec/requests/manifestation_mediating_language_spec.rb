# frozen_string_literal: true

require 'rails_helper'

# A translation made via an intermediate language (e.g. the Kalevala, translated from Russian rather than Finnish)
# names the mediating language after the translator -- in the page header (mobile and desktop variants) and in
# the metadata card -- since that is what the Hebrew text was translated from.
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
  # every place on the reading page that says who translated the text, and from what language
  let(:translator_lines) do
    {
      header_mobile: page.at_css('.work-page-top .work-and-author-names-mobile').text,
      header_desktop: page.at_css('.work-page-top .work-and-author-names-desktop').text,
      metadata_card: page.at_css('.headline-2-v02').text
    }
  end
  let(:source_language_row) { page.css('.metadata').find { |row| row.text.include?(I18n.t(:orig_lang)) } }

  after { Chewy.massacre }

  context 'when the expression has a mediating language' do
    before { text.expression.update_column(:mediating_language, 'ru') }

    it 'names the mediating language after the translator, in the header and the metadata card alike' do
      translator_lines.each do |where, line|
        expect(line).to include("(#{orig_lang_label('ru')})"), "#{where}: #{line.squish}"
        expect(line).not_to include(orig_lang_label('fi')), "#{where}: #{line.squish}"
      end
    end

    it "keeps the work's original language in the source language row" do
      expect(source_language_row.text).to include(I18n.t(:finnish))
    end

    it 'does not add a separate mediating language row' do
      expect(page.text).not_to include(I18n.t(:mediating_language))
    end
  end

  context 'when the expression has no mediating language' do
    it "names the work's original language after the translator everywhere, as before" do
      translator_lines.each do |where, line|
        expect(line).to include("(#{orig_lang_label('fi')})"), "#{where}: #{line.squish}"
      end
    end

    it 'still shows the source language row' do
      expect(source_language_row.text).to include(I18n.t(:finnish))
    end

    it 'does not mention a mediating language anywhere on the page' do
      expect(page.text).not_to include(I18n.t(:mediating_language))
    end
  end
end
