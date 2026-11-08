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

  it 'counts a Tagging on a nested sub-collection the author is not directly involved in' do
    # author is involved only in the outer collection; the tagging is on the inner
    # sub-collection, which appears on the author's page only via nesting.
    inner = create(:collection, manifestations: [prose_ru])
    create(:collection, authors: [author], included_collections: [inner])
    create(:tagging, taggable: inner, status: :approved)

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

  it 'reports the roles listing works, in presentation order' do
    create(:manifestation, author: create(:authority), translator: author, orig_lang: 'de', language: 'he')
    RefreshUncollectedWorksCollection.call(author) # the TOC tree lists uncollected works through it
    expect(described_class.call(author)[:roles]).to eq(%w(author translator))
  end

  context 'when the author is credited on a collection but not on all the texts in it' do
    let(:other_text) { create(:manifestation, author: create(:authority), orig_lang: 'de', language: 'he') }

    before do
      create(:collection, collection_type: :volume, translators: [author], manifestations: [other_text])
      RefreshUncollectedWorksCollection.call(author) # lists the author's own works
    end

    it 'offers no role under which only texts the author is not directly credited on are listed' do
      expect(described_class.call(author)[:roles]).to eq(%w(author))
    end
  end

  context 'when the author edited a collection, whose texts are therefore not listed on their page' do
    let(:edited) { create(:collection, editors: [author]) }

    before do
      create(:manifestation, author: create(:authority), editor: author, genre: 'drama', orig_lang: 'de',
                             collections: [edited])
    end

    it 'offers no editor role, as the edited collection lists no texts' do
      RefreshUncollectedWorksCollection.call(author) # lists the author's own works
      expect(described_class.call(author)[:roles]).to eq(%w(author))
    end

    it "offers no genre or language found only among the edited collection's texts" do
      data = described_class.call(author)
      expect(data[:genres]).to eq(Work::GENRES & %w(poetry prose))
      expect(data[:orig_langs]).to contain_exactly('he', 'ru')
    end

    it 'still offers those of a text in it that is listed under another role' do
      create(:manifestation, author: author, genre: 'article', orig_lang: 'en', collections: [edited])
      data = described_class.call(author)
      expect(data[:genres]).to include('article')
      expect(data[:orig_langs]).to include('en')
    end
  end
end
