# frozen_string_literal: true

require 'rails_helper'

# Server-side rendering of the Authority TOC filters pane and the per-node filter
# data attributes (bead ln5). JS behaviour is covered by the system spec.
RSpec.describe 'Author TOC filters (server-rendered)', type: :request do
  let(:author) { create(:authority, name: 'Filter Author') }
  let(:volume) { create(:collection, title: 'A Volume', collection_type: :volume) }

  let!(:poem) do
    create(:manifestation, title: 'Alpha Poem', author: author, genre: 'poetry', orig_lang: 'he', language: 'he')
  end
  let!(:story) do
    create(:manifestation, title: 'Beta Story', author: author, genre: 'prose', orig_lang: 'ru', language: 'he')
  end

  before do
    create(:collection_item, collection: volume, item: poem)
    create(:collection_item, collection: volume, item: story)
    create(:involved_authority, authority: author, item: volume, role: 'editor')
    create(:recommendation, manifestation: poem, status: :approved)
  end

  it 'renders the hidden filters pane with dynamic genre and language options' do
    get authority_path(author)
    expect(response).to have_http_status(:ok)

    expect(rendered).to have_css('#toc_filters_pane', visible: :all)
    # genres actually present become checkbox options
    expect(rendered).to have_css('#toc-filter-genre-poetry', visible: :all)
    expect(rendered).to have_css('#toc-filter-genre-prose', visible: :all)
    # a translated source language present => the "translation" option and its sub-language
    expect(rendered).to have_css('#toc-filter-translated', visible: :all)
    expect(rendered).to have_css('#toc-filter-lang-ru', visible: :all)
  end

  it 'tags each manifestation node with the data attributes used for filtering' do
    get authority_path(author)

    node = rendered.first("[data-mid='#{poem.id}']", visible: :all)
    expect(node).to be_present
    expect(node[:'data-genre']).to eq('poetry')
    expect(node[:'data-orig-lang']).to eq('he')
    # poem has an approved recommendation => curatorial flag set
    expect(node[:'data-recommended']).to eq('1')
  end

  it 'offers a role filter for the roles the author has published works in' do
    get authority_path(author)

    # author of both works and editor of the volume containing them
    expect(rendered).to have_css('#toc-filter-role-author', visible: :all)
    expect(rendered).to have_css('#toc-filter-role-editor', visible: :all)
    expect(rendered).to have_no_css('#toc-filter-role-translator', visible: :all)
    # each node records the role section it was rendered under
    roles = rendered.all("[data-mid='#{poem.id}']", visible: :all).pluck(:'data-role')
    expect(roles).to contain_exactly('author', 'editor')
  end

  it 'omits the role filter when the author has a single role' do
    solo = create(:authority)
    create(:manifestation, author: solo)
    get authority_path(solo)

    expect(rendered).to have_css('#toc_filters_pane', visible: :all)
    expect(rendered).to have_no_css('.toc-filter-role', visible: :all)
  end

  it 'sets data-tagging for a directly-tagged manifestation' do
    create(:tagging, taggable: story, status: :approved)
    get authority_path(author)

    node = rendered.first("[data-mid='#{story.id}']", visible: :all)
    expect(node[:'data-tagging']).to eq('1')
  end

  it 'sets data-tagging on members of a tagged collection' do
    create(:tagging, taggable: volume, status: :approved)
    get authority_path(author)

    poem_node = rendered.first("[data-mid='#{poem.id}']", visible: :all)
    story_node = rendered.first("[data-mid='#{story.id}']", visible: :all)
    expect(poem_node[:'data-tagging']).to eq('1')
    expect(story_node[:'data-tagging']).to eq('1')
  end

  it 'uses the /works-style collapsible block for filter sections' do
    get authority_path(author)
    # same accordion mechanism as /works filtering: .vertical-expand.fcoll toggling a .collapse block
    expect(rendered).to have_css('#toc_filters_pane .vertical-expand.fcoll', visible: :all)
    expect(rendered).to have_css('#toc_filters_pane .nested.collapse', visible: :all)
  end
end
