# frozen_string_literal: true

require 'rails_helper'

# When the same collection is listed under more than one role on an authority's page (e.g. as
# both author and editor of it), each TOC copy needs its own DOM id and each navbar link has to
# point at its own copy, rather than every link leading to the first one.
RSpec.describe 'Authority TOC anchors for a collection in several roles', type: :request do
  let(:person) { create(:authority, :published, uncollected_works_collection: create(:collection, :uncollected)) }
  let(:volume) do
    create(:collection, title: 'Kesheth', collection_type: :volume, authors: [person], editors: [person])
  end

  before do
    create(:manifestation, title: 'A Poem', author: person, collections: [volume])
    get authority_path(person)
  end

  it 'gives each rendering of the collection a distinct id' do
    ids = Nokogiri::HTML(response.body).css(".cwrapper[data-collection-id='#{volume.id}']").pluck('id')
    expect(ids.size).to be >= 2
    expect(ids).to eq(ids.uniq)
  end

  it 'points every navbar link at an existing, distinct TOC element' do
    doc = Nokogiri::HTML(response.body)
    targets = doc.css(".nav-link-chapter[data-collection-id='#{volume.id}']").pluck('data-scroll-target')
    expect(targets.size).to be >= 2
    expect(targets).to eq(targets.uniq)
    targets.each { |target| expect(doc.css(".cwrapper#{target}")).not_to be_empty }
  end
end
