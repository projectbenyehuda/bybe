# frozen_string_literal: true

require 'rails_helper'

# Regression test for the manage_toc TOC losing its drag/transplant editing UI.
#
# The manage_toc view (authors#manage_toc -> shared/_manage_toc ->
# collections_migration/_gentoc) must render collections the author is involved
# with *at collection level* through the editable partial chain
# (_toc_node -> shared/_manage_collection -> shared/_editable_collection), which
# is what wires up the SortableJS drag handles used to reorder/transplant items.
#
# A refactor accidentally passed `editable: false` from _gentoc, dropping the
# editable branch entirely so nothing was draggable. This spec asserts the drag
# handles are present.
describe 'manage_toc draggable collections', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_catalog_editor
  end

  let!(:author) { create(:authority, name: 'Draggable Author') }

  # A collection the author is involved with at collection level -> renders via
  # the editable branch of _toc_node.
  let!(:volume) do
    create(:collection, title: 'Draggable Volume', collection_type: :volume)
  end

  let!(:involved_authority) do
    create(:involved_authority, authority: author, item: volume, role: 'author')
  end

  let!(:work_in_volume) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Work In Volume', status: :published, author: author)
    end
  end

  let!(:collection_item) do
    create(:collection_item, collection: volume, item: work_in_volume)
  end

  after { Chewy.massacre }

  it 'renders the SortableJS drag handles for collection-level items' do
    visit authors_manage_toc_path(author)

    # Sanity: the collections management area rendered.
    expect(page).to have_css('#coll_toc')

    # The editable collection container and its draggable item with a drag
    # handle are only emitted by shared/_editable_collection, i.e. only when
    # `editable` is true. Their presence is the regression guard.
    expect(page).to have_css('.collection.connectable')
    expect(page).to have_css('.collection_draggable_item')
    expect(page).to have_css('.collection_draggable_item .drag-handle')
  end
end
