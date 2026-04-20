# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LexiconHelper, type: :helper do
  describe '#render_external_identifiers' do
    it 'returns nil when external_identifiers is blank' do
      expect(helper.render_external_identifiers(nil)).to be_nil
      expect(helper.render_external_identifiers({})).to be_nil
    end

    it 'renders LC identifier with correct URL' do
      result = helper.render_external_identifiers({ 'lc' => 'n79021164' })
      expect(result).to include('LC –')
      expect(result).to include('https://id.loc.gov/authorities/n79021164')
      expect(result).to include('n79021164')
    end

    it 'renders VIAF identifier with correct URL' do
      result = helper.render_external_identifiers({ 'viaf' => '36924286' })
      expect(result).to include('VIAF –')
      expect(result).to include('https://viaf.org/viaf/36924286')
    end

    it 'renders NLI identifier with correct URL' do
      result = helper.render_external_identifiers({ 'nli' => '000123456' })
      expect(result).to include('NLI –')
      expect(result).to include('http://uli.nli.org.il/authorities/000123456')
    end

    it 'renders Wikidata identifier with correct URL' do
      result = helper.render_external_identifiers({ 'wikidata' => 'Q12345' })
      expect(result).to include('Wikidata –')
      expect(result).to include('https://www.wikidata.org/wiki/Q12345')
    end

    it 'renders OpenLibrary identifier with correct URL' do
      result = helper.render_external_identifiers({ 'openlibrary' => 'OL1234567A' })
      expect(result).to include('OpenLibrary –')
      expect(result).to include('https://openlibrary.org/authors/OL1234567A')
    end

    it 'skips unknown identifier keys like j9u' do
      result = helper.render_external_identifiers({ 'j9u' => '987654321' })
      expect(result).to be_nil
    end

    it 'joins multiple identifiers with vertical pipes' do
      result = helper.render_external_identifiers({ 'lc' => 'n79021164', 'viaf' => '36924286' })
      expect(result).to include(' | ')
      expect(result).to include('LC –')
      expect(result).to include('VIAF –')
    end

    it 'returns nil when all keys are unknown' do
      result = helper.render_external_identifiers({ 'j9u' => '123', 'unknown' => '456' })
      expect(result).to be_nil
    end

    it 'renders links opening in a new tab' do
      result = helper.render_external_identifiers({ 'lc' => 'n79021164' })
      expect(result).to include('target="_blank"')
      expect(result).to include('rel="noopener noreferrer"')
    end
  end
end
