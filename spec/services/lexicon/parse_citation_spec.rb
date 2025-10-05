# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ParseCitation do
  subject(:result) { described_class.call(list_item) }

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
        from_publication: 'ארה',
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
        from_publication: nil, # TODO: should be 'ליריקה גבישית'
        pages: '6'
      )
    end
  end
end
