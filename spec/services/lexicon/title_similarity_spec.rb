# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::TitleSimilarity do
  # The score a match proposal must reach to be shown to the editor
  let(:threshold) { described_class::MATCH_THRESHOLD }

  def similarity(title_a, title_b, ignoring: nil)
    described_class.call(title_a, title_b, ignoring: ignoring)
  end

  it 'scores identical titles 100' do
    expect(similarity('ספר התענוגות', 'ספר התענוגות')).to eq(100)
  end

  it 'ignores differences in bibliographic punctuation' do
    expect(similarity('מחזות : חברים מספרים על ישו : כי עודני מאמין בך',
                      'מחזות: חברים מספרים על ישו ; כי עודני מאמין בך')).to eq(100)
  end

  it 'ignores the statement of responsibility after the slash' do
    expect(similarity('חמור הזהב / לוקיוס אפוליאוס', 'חמור הזהב')).to eq(100)
  end

  it 'ignores the given name wherever it appears' do
    expect(similarity('Another Book', 'Test Author: Another Book', ignoring: 'Test Author')).to eq(100)
  end

  # The bibliography credits the author after the title, the lexicon files before it
  it 'finds the title on either side of the slash' do
    expect(similarity('ספר התענוגות / עמוס קינן.', 'עמוס קינן / ספר התענוגות', ignoring: 'עמוס קינן'))
      .to eq(100)
  end

  it 'ignores Hebrew points' do
    expect(similarity('הלבן', 'הֵלֵּבָּן')).to eq(100)
  end

  it 'reads the maqaf as separating two words rather than as a point' do
    expect(similarity('לין יו־טאנג', 'לין יו-טאנג')).to eq(100)
  end

  it 'ignores word order' do
    expect(similarity('מכתבים אל אמא', 'אל אמא : מכתבים')).to eq(100)
  end

  # The case that prompted this scoring: same book, differently punctuated, with a subtitle
  # present on the bibliography side only.
  it 'proposes a title that the other side extends with a subtitle' do
    expect(similarity('בלוק 23 : מכתבים מנס ציונה', 'בלוק 23 ; מכתבים מנס ציונה : נובלות'))
      .to be >= threshold
  end

  it 'proposes a title with a spelling variant' do
    expect(similarity('אין לי עכשיו', 'אין לי עכשו / אבות ישורון')).to be >= threshold
  end

  it 'proposes a title with a typo' do
    expect(similarity('The Great Book', 'The Grate Book')).to be >= threshold
  end

  it 'does not propose unrelated titles' do
    expect(similarity('Completely Unrelated Title', 'Different Title')).to be < threshold
  end

  # DamerauLevenshtein#distance gives up at its max_distance argument (10 by default) and
  # reports that bound rather than the real distance; taken at face value for long titles it
  # reads as near-identity, and every long publication title matched every work.
  it 'does not propose unrelated long titles' do
    expect(similarity('מסע אל תוך הלילה הארוך של אירופה בשנות המלחמה הגדולה',
                      'שירים מן הגליל העליון ומן העמק בימי ראשית ההתיישבות')).to be < threshold
  end

  it 'does not propose a title that the other side merely begins with' do
    expect(similarity('שירים', 'שירים ופזמונות לילדים ולנוער')).to be < threshold
  end

  it 'scores a blank title 0' do
    expect(similarity('', 'ספר התענוגות')).to eq(0)
    expect(similarity(nil, 'ספר התענוגות')).to eq(0)
  end

  it 'compares the credits themselves when there is nothing else to compare' do
    expect(similarity(' / אבות ישורון', ' / אבות ישורון')).to eq(100)
  end
end
