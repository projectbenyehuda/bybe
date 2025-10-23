# frozen_string_literal: true

RSpec.shared_context 'when authority has several collections' do
  let!(:authority) { create(:authority, uncollected_works_collection: uncollected_collection) }
  let!(:other_authority) { create(:authority) }

  let!(:top_level_collection) { create(:collection) }
  let!(:top_level_collection_with_nested_collections) do
    create(
      :collection,
      authors: [other_authority],
      included_collections: [nested_edited_collection, nested_translated_collection]
    )
  end
  let!(:uncollected_collection) { create(:collection, :uncollected) }
  let!(:nested_edited_collection) { create(:collection, editors: [authority]) }
  let!(:nested_translated_collection) do
    create(:collection, translators: [authority], included_collections: [nested_translated_subcollection])
  end
  let!(:nested_translated_subcollection) do
    create(
      :collection,
      translators: [authority],
      title_placeholders: ['Title placeholder'],
      markdown_placeholders: ['Markdown placeholder']
    )
  end

  let!(:edited_manifestations) do
    create_list(
      :manifestation,
      3,
      collections: [nested_edited_collection],
      editor: authority,
      author: other_authority
    )
  end
  # For translated manifestations we don's specify authority on manifestaton level
  let!(:translated_manifestations) do
    create_list(
      :manifestation,
      2,
      collections: [nested_translated_collection],
      author: other_authority
    )
  end

  let!(:uncollected_manifestations) do
    create_list(:manifestation, 2, author: authority, collections: [uncollected_collection])
  end

  let!(:top_level_manifestations) do
    create_list(:manifestation, 3, author: authority, collections: [top_level_collection])
  end
end
