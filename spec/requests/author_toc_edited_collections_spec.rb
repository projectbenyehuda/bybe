# frozen_string_literal: true

require 'rails_helper'

# On the page of an authority who edited a collection, that collection is listed by its title
# only: the title links to the collection, but the texts in it (its authors' works) are not
# listed, so they are not reachable from the editor's page nor part of its flat list and filters.
RSpec.describe 'Authority TOC edited collections', type: :request do
  subject(:call) { get authority_path(editor) }

  let(:editor) { create(:authority, :published, uncollected_works_collection: create(:collection, :uncollected)) }
  let(:other_authority) { create(:authority) }
  let(:anthology) do
    create(:collection, title: 'Edited Anthology', collection_type: :volume, editors: [editor])
  end
  let(:anthology_text) do
    create(:manifestation, title: 'Somebody Elses Story', author: other_authority, editor: editor,
                           collections: [anthology])
  end
  let(:own_text) do
    create(:manifestation, title: 'An Own Story', author: editor, collections: [anthology])
  end
  let(:own_volume_text) do
    create(:manifestation, title: 'A Text In Own Volume', author: editor,
                           collections: [create(:collection, title: 'Own Volume', authors: [editor])])
  end

  before do
    anthology_text
    own_text
    own_volume_text
    call
  end

  it 'lists the edited collection with its title linking to the collection' do
    expect(response.body).to include('id="works-editor-collection-level"')
    expect(response.body).to include(%(href="#{collection_path(anthology)}"))
  end

  it 'does not list the texts of the edited collection' do
    expect(response.body).not_to include('Somebody Elses Story')
    expect(response.body).not_to include(%(href="#{manifestation_path(anthology_text)}"))
  end

  it 'still lists the edited collection in the navbar' do
    expect(navbar_fragment(response.body)).to include(%(data-scroll-target="#cwrapper_#{anthology.id}"))
  end

  it "still lists the editor's own texts, including those in the edited collection" do
    expect(response.body).to include(%(href="#{manifestation_path(own_volume_text)}"))
    expect(response.body).to include(%(href="#{manifestation_path(own_text)}"))
  end
end
