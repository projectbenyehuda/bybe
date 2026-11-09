# frozen_string_literal: true

require 'rails_helper'

describe ConvertManifestationToCollection do
  subject(:result) { described_class.call(manifestation, collection_type) }

  let(:collection_type) { 'series' }
  let(:author) { create(:authority) }
  let(:translator) { create(:authority) }
  let(:markdown) do
    <<~MD
      ## First poem
      Line one of the first poem.

      ### A section of the first
      More of the first.

      ## Second poem
      The second.

      #### Deep heading

      ## Third poem
      The third.
    MD
  end
  let!(:manifestation) do
    create(:manifestation, title: 'Poems', markdown: markdown, author: author, orig_lang: 'ru',
                           translator: translator, genre: 'poetry', publisher: 'Original Publisher',
                           publication_date: '1925', comment: 'A comment')
  end
  let(:collection) { result[:collection] }
  let(:texts) { collection.collection_items.order(:seqno).map(&:item) }

  describe 'validation' do
    context 'when the text has a single top-level heading' do
      let(:markdown) { "## Only\nText\n### Sub\nMore\n" }

      it 'fails and changes nothing' do
        expect { result }.not_to(change { [Collection.count, Manifestation.count] })
        expect(result).to eq(success: false, error: I18n.t(:convert_to_collection_too_few_headings))
        expect(manifestation.reload.title).to eq('Poems')
        expect(manifestation.markdown).to eq(markdown)
      end
    end

    context 'when a top-level heading is blank' do
      let(:markdown) { "## One\nText\n##\nMore\n" }

      it 'fails' do
        expect(result).to eq(success: false, error: I18n.t(:convert_to_collection_blank_heading))
      end
    end

    context 'when the collection type is the system type' do
      let(:collection_type) { 'uncollected' }

      it 'fails' do
        expect { result }.not_to change(Collection, :count)
        expect(result).to eq(success: false, error: I18n.t(:convert_to_collection_bad_type))
      end
    end

    context 'when the collection type is unknown' do
      let(:collection_type) { 'bogus' }

      it 'fails' do
        expect(result[:success]).to be false
      end
    end
  end

  describe 'the conversion' do
    it 'creates a collection of the requested type, titled like the original text' do
      expect(result[:success]).to be true
      expect(collection).to be_series
      expect(collection.title).to eq('Poems')
    end

    it 'creates one text per top-level heading, in order' do
      expect { result }.to change(Manifestation, :count).by(2)
                                                        .and change(Expression, :count).by(2)
                                                                                       .and change(Work, :count).by(2)
      expect(texts.map(&:title)).to eq(['First poem', 'Second poem', 'Third poem'])
      expect(collection.collection_items.order(:seqno).pluck(:seqno)).to eq([1, 2, 3])
    end

    it 'keeps the original manifestation, expression and work as the first text, retitled' do
      expression = manifestation.expression
      work = expression.work
      result
      expect(texts.first.id).to eq(manifestation.id)
      expect(manifestation.reload.title).to eq('First poem')
      expect(expression.reload.title).to eq('First poem')
      expect(work.reload.title).to eq('First poem')
      expect(manifestation.expression_id).to eq(expression.id)
    end

    it 'drops the title heading and promotes the remaining headings by one level' do
      result
      expect(texts[0].markdown).to eq("Line one of the first poem.\n\n## A section of the first\nMore of the first.")
      expect(texts[1].markdown).to eq("The second.\n\n### Deep heading")
      expect(texts[2].markdown).to eq('The third.')
    end

    it 'gives each new text its own expression and work, copying the original metadata' do
      original_expression = manifestation.expression
      original_work = original_expression.work
      result
      texts.drop(1).each do |text|
        expect(text.expression).not_to eq(original_expression)
        expect(text.expression.work).not_to eq(original_work)
        expect(text.expression.title).to eq(text.title)
        expect(text.expression.work.title).to eq(text.title)
        expect(text.publisher).to eq('Original Publisher')
        expect(text.publication_date).to eq('1925')
        expect(text.comment).to eq('A comment')
        expect(text).to be_published
        expect(text.expression.language).to eq(original_expression.language)
        expect(text.expression.intellectual_property).to eq(original_expression.intellectual_property)
        expect(text.expression.period).to eq(original_expression.period)
        expect(text.expression.work.genre).to eq('poetry')
        expect(text.expression.work.orig_lang).to eq('ru')
      end
    end

    it 'copies the involved authorities of the work and the expression' do
      result
      texts.drop(1).each do |text|
        expect(text.expression.work.involved_authorities.map { |ia| [ia.authority, ia.role] })
          .to eq([[author, 'author']])
        expect(text.expression.involved_authorities.map { |ia| [ia.authority, ia.role] })
          .to eq([[translator, 'translator']])
        expect(text.authors).to eq([author])
        expect(text.translators).to eq([translator])
      end
    end

    it 'credits the collection with the original authorities' do
      result
      expect(collection.involved_authorities.map { |ia| [ia.authority, ia.role] })
        .to contain_exactly([author, 'author'], [translator, 'translator'])
    end

    it 'does not carry over the original popularity, title variants or heading cache' do
      manifestation.update!(impressions_count: 500)
      result
      texts.drop(1).each do |text|
        expect(text.impressions_count).to eq(0)
        expect(text.alternate_titles.to_s).not_to include('Poems')
        expect(text.heading_lines).to be_empty
      end
      expect(texts[0].reload.alternate_titles.to_s).not_to include('Poems')
      expect(texts[0].heading_lines).to eq([2])
    end

    it 'recomputes the word count of each text' do
      result
      expect(texts.map(&:word_count)).to eq(texts.map { |t| t.markdown.split.length })
    end
  end

  describe 'footnotes' do
    let(:markdown) do
      <<~MD
        ## First[^1]
        Text with a note[^2].

        ## Second
        Another note[^3] and a named one[^ftn4].

        [^1]: Note on the first title.

        [^2]: Note in the first text,
        continued on a second line.

        [^3]: Note in the second text.

        [^ftn4]: A named note.

        [^9]: Unreferenced note.
      MD
    end

    it 'gives each text the footnote bodies it references' do
      result
      expect(texts[0].markdown).to eq(
        "[^1]\nText with a note[^2].\n\n[^1]: Note on the first title.\n\n" \
        "[^2]: Note in the first text,\ncontinued on a second line.\n"
      )
      expect(texts[1].markdown).to eq(
        "Another note[^3] and a named one[^ftn4].\n\n[^3]: Note in the second text.\n\n" \
        "[^ftn4]: A named note.\n\n[^9]: Unreferenced note.\n"
      )
    end

    it 'strips footnote markers from titles' do
      result
      expect(texts.map(&:title)).to eq(%w(First Second))
    end
  end

  describe 'text preceding the first heading' do
    let(:markdown) { "An introduction.\n\n## One\nFirst.\n## Two\nSecond.\n" }

    it 'is kept as a markdown placeholder at the top of the collection' do
      result
      items = collection.collection_items.order(:seqno)
      expect(items.first.item).to be_nil
      expect(items.first.markdown).to eq('An introduction.')
      expect(items.drop(1).map { |ci| ci.item.title }).to eq(%w(One Two))
    end

    context 'when it is blank' do
      let(:markdown) { "\n\n## One\nFirst.\n## Two\nSecond.\n" }

      it 'adds no placeholder' do
        result
        expect(collection.collection_items.count).to eq(2)
      end
    end
  end

  describe 'containing collections' do
    let(:volume) { create(:collection, collection_type: :volume) }
    let(:before) { create(:manifestation) }
    let(:after) { create(:manifestation) }

    before do
      create(:collection_item, collection: volume, item: before, seqno: 1)
      create(:collection_item, collection: volume, item: manifestation, seqno: 2)
      create(:collection_item, collection: volume, item: after, seqno: 3)
    end

    it 'puts the new collection in the place the text occupied' do
      result
      expect(volume.collection_items.reload.order(:seqno).map(&:item)).to eq([before, collection, after])
      expect(CollectionItem.where(item: manifestation).pluck(:collection_id)).to eq([collection.id])
    end

    it 'drops the text from an uncollected-works collection rather than nesting the collection there' do
      uncollected = create(:collection, :uncollected)
      create(:collection_item, collection: uncollected, item: manifestation, seqno: 1)
      result
      expect(uncollected.collection_items.reload).to be_empty
    end
  end

  context 'when something fails midway' do
    before do
      allow_any_instance_of(Manifestation).to receive(:recalc_word_count).and_raise('boom') # rubocop:disable RSpec/AnyInstance
    end

    it 'rolls everything back' do
      expect { result }.not_to(change { [Collection.count, Manifestation.count, Work.count, Expression.count] })
      expect(result).to eq(success: false, error: 'boom')
      expect(manifestation.reload.title).to eq('Poems')
    end
  end
end
