# frozen_string_literal: true

require 'rails_helper'

describe IngestibleText do
  describe 'per-text flags' do
    it 'defaults secondary and sefaria_linker to false' do
      text = described_class.new({ 'title' => 'T', 'content' => 'C' })
      expect(text).to have_attributes(secondary: false, sefaria_linker: false)
    end

    it 'casts checkbox string values to booleans' do
      text = described_class.new({ 'title' => 'T', 'content' => 'C', 'secondary' => '1', 'sefaria_linker' => '0' })
      expect(text).to have_attributes(secondary: true, sefaria_linker: false)
    end

    it 'includes the flags in its hash representation' do
      text = described_class.new({ 'title' => 'T', 'content' => 'C', 'secondary' => true, 'sefaria_linker' => true })
      expect(text.to_hash).to eq({ title: 'T', content: 'C', secondary: true, sefaria_linker: true })
    end
  end
end
