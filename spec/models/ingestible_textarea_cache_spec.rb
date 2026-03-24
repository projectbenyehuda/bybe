# frozen_string_literal: true

require 'rails_helper'

describe Ingestible do
  describe '#save_text_to_cache' do
    let(:ingestible) { create(:ingestible) }

    it 'saves a version when cache is empty' do
      ingestible.save_text_to_cache('My Title', 'Some content')
      cache = ingestible.parsed_textarea_cache
      expect(cache.length).to eq(1)
      expect(cache.first['title']).to eq('My Title')
      expect(cache.first['content']).to eq('Some content')
      expect(cache.first['saved_at']).to be_present
    end

    it 'saves a new version when content differs from latest for that title' do
      ingestible.save_text_to_cache('My Title', 'Version 1')
      ingestible.save_text_to_cache('My Title', 'Version 2')
      cache = ingestible.parsed_textarea_cache
      expect(cache.length).to eq(2)
    end

    it 'does not save a duplicate if content matches the latest version for that title' do
      ingestible.save_text_to_cache('My Title', 'Same content')
      ingestible.save_text_to_cache('My Title', 'Same content')
      expect(ingestible.parsed_textarea_cache.length).to eq(1)
    end

    it 'saves versions for multiple different titles independently' do
      ingestible.save_text_to_cache('Title A', 'Content A')
      ingestible.save_text_to_cache('Title B', 'Content B')
      cache = ingestible.parsed_textarea_cache
      expect(cache.length).to eq(2)
      expect(cache.map { |v| v['title'] }).to contain_exactly('Title A', 'Title B')
    end

    it 'does not save when title is blank' do
      ingestible.save_text_to_cache('', 'Some content')
      expect(ingestible.parsed_textarea_cache).to be_empty
    end

    it 'does not save when content is nil' do
      ingestible.save_text_to_cache('My Title', nil)
      expect(ingestible.parsed_textarea_cache).to be_empty
    end

    it 'saves a new version for title A even if latest content for title B is same' do
      ingestible.save_text_to_cache('Title A', 'Content')
      ingestible.save_text_to_cache('Title B', 'Content')
      # Both should be saved because they're different titles
      expect(ingestible.parsed_textarea_cache.length).to eq(2)
    end
  end

  describe '#parsed_textarea_cache' do
    let(:ingestible) { create(:ingestible) }

    it 'returns an empty array when cache is nil' do
      expect(ingestible.parsed_textarea_cache).to eq([])
    end

    it 'returns parsed JSON when cache is populated' do
      ingestible.update_columns(textarea_cache: [{ title: 'T', content: 'C', saved_at: '2024-01-01T10:00:00Z' }].to_json)
      result = ingestible.parsed_textarea_cache
      expect(result).to be_an(Array)
      expect(result.first['title']).to eq('T')
    end

    it 'returns empty array on invalid JSON' do
      ingestible.update_columns(textarea_cache: 'not valid json}')
      expect(ingestible.parsed_textarea_cache).to eq([])
    end
  end
end
