# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthorTocFilterData do
  let(:author) { create(:authority) }

  let!(:poem_he) do
    create(:manifestation, author: author, genre: 'poetry', orig_lang: 'he', language: 'he')
  end
  let!(:prose_ru) do
    create(:manifestation, author: author, genre: 'prose', orig_lang: 'ru', language: 'he')
  end

  it 'reports the genres present, ordered by the canonical genre order' do
    data = described_class.call(author)
    expect(data[:genres]).to eq(Work::GENRES & %w(poetry prose))
  end

  it 'reports the source languages present' do
    data = described_class.call(author)
    expect(data[:orig_langs]).to contain_exactly('he', 'ru')
  end

  it 'collects featured, approved-recommended and incoming-aboutness manifestation ids' do
    create(:featured_content, manifestation: poem_he)
    create(:recommendation, manifestation: prose_ru, status: :approved)
    create(:recommendation, manifestation: poem_he, status: :pending) # excluded: not approved
    create(:aboutness, aboutable: poem_he)

    data = described_class.call(author)

    expect(data[:featured_ids]).to contain_exactly(poem_he.id)
    expect(data[:recommended_ids]).to contain_exactly(prose_ru.id)
    expect(data[:aboutness_ids]).to contain_exactly(poem_he.id)
  end

  it 'collects manifestation ids bearing an approved direct Tagging' do
    create(:tagging, taggable: poem_he, status: :approved)
    create(:tagging, taggable: prose_ru, status: :pending) # excluded: not approved

    data = described_class.call(author)

    expect(data[:tagging_ids]).to contain_exactly(poem_he.id)
  end

  it 'counts an approved Tagging on a collection towards its member manifestations' do
    collection = create(:collection, authors: [author], manifestations: [prose_ru])
    create(:tagging, taggable: collection, status: :approved)

    data = described_class.call(author)

    expect(data[:tagging_ids]).to contain_exactly(prose_ru.id)
  end

  it 'cascades an approved collection Tagging into nested sub-collections' do
    inner = create(:collection, manifestations: [prose_ru])
    outer = create(:collection, authors: [author], included_collections: [inner])
    create(:tagging, taggable: outer, status: :approved)

    data = described_class.call(author)

    expect(data[:tagging_ids]).to contain_exactly(prose_ru.id)
  end

  it 'ignores a pending Tagging on a collection' do
    collection = create(:collection, authors: [author], manifestations: [prose_ru])
    create(:tagging, taggable: collection, status: :pending)

    data = described_class.call(author)

    expect(data[:tagging_ids]).to be_empty
  end

  it 'returns empty sets when the author has no curatorial content' do
    data = described_class.call(author)
    expect(data[:featured_ids]).to be_empty
    expect(data[:recommended_ids]).to be_empty
    expect(data[:aboutness_ids]).to be_empty
    expect(data[:tagging_ids]).to be_empty
  end
end
