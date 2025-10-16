# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ParseCitation do
  subject(:result) { described_class.call(list_item, from_publication) }

  let(:from_publication) { Faker::Book.title }
  let(:list_item) { Nokogiri::HTML(markup) }

  context "when there is a link to author's page" do
    let(:markup) do
      <<~HTML
        <li><b><a href="00019.php">וויינר, חיים.</a></b>&nbsp; "ארה".&nbsp;&nbsp; בספרו: <b>פרקי חיים וספרות</b> / ליקט וכינס זאב וויינר#{' '}
          (ירושלים : קרית-ספר, תש"ך 1960), עמ' 89־90 &lt;פורסם לראשונה ב"הדואר",#{' '}
          7 בפברואר 1930&gt;</li>
      HTML
    end

    it 'parses successfully' do
      expect(result).to have_attributes(
        authors: 'וויינר, חיים.',
        from_publication: from_publication,
        title: '"ארה". בספרו: פרקי חיים וספרות / ליקט וכינס זאב וויינר (ירושלים : קרית-ספר, תש"ך 1960)'\
                ', <פורסם לראשונה ב"הדואר", 7 בפברואר 1930>',
        pages: '89־90'
      )
    end
  end

  context "when there is no link to author's page" do
    let(:markup) do
      <<~HTML
        <li><b>גוטקינד, נעמי.</b>  ליריקה גבישית.  <u>הצופה</u>, ט״ו בסיון תש״ן, 8 ביוני 1990, עמ׳ 6.</li>
      HTML
    end

    it 'parses successfully' do
      expect(result).to have_attributes(
        authors: 'גוטקינד, נעמי.',
        from_publication: from_publication,
        title: 'ליריקה גבישית. הצופה, ט״ו בסיון תש״ן, 8 ביוני 1990',
        pages: '6'
      )
    end
  end

  context 'when citation is in English' do
    let(:markup) do
      <<~HTML
        <li><b>Itzhaki, Masha.</b>  Gabriela Avigur Rotem:
        ״Canicule et oiseaux fous״.
        <u>Les cahiers du judaisme</u>, num. 20 (2006), pp. 135–136.</li>
      HTML
    end

    it 'parses successfully' do
      expect(result).to have_attributes(
        authors: 'Itzhaki, Masha.',
        from_publication: from_publication,
        title: 'Gabriela Avigur Rotem: ״Canicule et oiseaux fous״. Les cahiers du judaisme, num. 20 (2006)',
        pages: '135–136'
      )
    end
  end
end
