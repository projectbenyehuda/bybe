# frozen_string_literal: true

require 'rails_helper'

# visual_art is the last entry in Work::GENRES, so every genre list should show it after lexicon
# and right before the translations pseudo-genre.
RSpec.describe 'Visual art genre', type: :request do
  around do |example|
    I18n.with_locale(:he) { example.run }
  end

  let(:page) { Nokogiri::HTML(response.body) }
  let(:visual_art_href) { manifestation_genre_path(genre: 'visual_art') }
  let(:lexicon_href) { manifestation_genre_path(genre: 'lexicon') }

  def hrefs_in(selector)
    container = page.at_css(selector)
    expect(container).not_to be_nil, "#{selector} is missing from the page"
    container.css('a').pluck('href')
  end

  before do
    clean_tables
    create(:manifestation, genre: 'visual_art')
    get root_path
  end

  it 'shows a visual art card on the homepage, after lexicon and before translations' do
    hrefs = hrefs_in('#genre')
    expect(hrefs).to include(visual_art_href)
    expect(hrefs.index(visual_art_href)).to be > hrefs.index(lexicon_href)
    expect(hrefs.index(visual_art_href)).to be < hrefs.index(translations_path)
    expect(page.at_css('#genre').text).to include('אמנות חזותית')
  end

  it 'lists visual art in the top menu genre dropdown, right before translations' do
    hrefs = hrefs_in('#menu-genres')
    expect(hrefs.index(visual_art_href)).to eq(hrefs.index(translations_path) - 1)
  end
end
