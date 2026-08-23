# frozen_string_literal: true

require 'rails_helper'

describe DetectSuspectedTypos do
  subject(:findings) { described_class.call(markdown, genre) }

  let(:genre) { 'prose' }

  def types
    findings.pluck(:type)
  end

  describe 'digits inside words' do
    context 'when a digit is welded onto a Hebrew letter' do
      let(:markdown) { "הוא נכנס לבי1ת ויצא\n" }

      it 'reports the word with its line and context' do
        expect(findings).to contain_exactly(
          hash_including(type: :digit_in_word, line: 1, text: 'הוא נכנס לבי1ת ויצא')
        )
      end
    end

    context 'when a digit follows a maqaf' do
      # U+05BE maqaf is punctuation, not a combining mark, so 'ה־1948' is a legitimate form
      let(:markdown) { "בשנת ה־1948 היה הדבר\n" }

      it { is_expected.to be_empty }
    end

    context 'when digits stand alone as a number' do
      let(:markdown) { "בשנת 1948 היה הדבר\n" }

      it { is_expected.to be_empty }
    end

    context 'when a footnote reference follows a word' do
      let(:markdown) { "הוא נכנס לבית[^12] ויצא\n" }

      it { is_expected.to be_empty }
    end

    context 'when a footnote identifier mixes digits and Hebrew letters' do
      let(:markdown) { "וְעַד מִנִּית [^ftn3א] וְעוֹד\n\n[^ftn3א]:  שופטים י\"א\n" }

      it { is_expected.to be_empty }
    end

    context 'when an image filename mixes digits and Hebrew letters' do
      let(:markdown) { "![תמונה155-156.png](/rails/active_storage/x.png)\n" }

      it { is_expected.to be_empty }
    end

    context 'when a space is missing before a number' do
      let(:markdown) { "העיתון נוסד ב1919 בירושלים\n" }

      it 'reports it' do
        expect(types).to eq([:digit_in_word])
      end
    end
  end

  describe 'final letters in the middle of a word' do
    context 'when a final mem opens a word' do
      let(:markdown) { "םים רבים כאן\n" }

      it 'reports the word' do
        expect(findings).to contain_exactly(hash_including(type: :final_mid_word, match: 'םים', line: 1))
      end
    end

    context 'when the final letter is where it belongs' do
      let(:markdown) { "מים רבים כאן\n" }

      it { is_expected.to be_empty }
    end

    context 'when a final letter carries nikkud and ends the word' do
      let(:markdown) { "מַה שְׁלוֹמְךָ היום\n" }

      it { is_expected.to be_empty }
    end

    context 'when the token is an acronym' do
      let(:markdown) { "צה\"ל הודיע היום\n" }

      it { is_expected.to be_empty }
    end
  end

  describe 'non-final letters at the end of a word' do
    context 'when a word ends in an ordinary kaf' do
      let(:markdown) { "אכ הוא הלכ הביתה\n" }

      it 'reports every such word' do
        expect(findings.pluck(:match)).to eq(%w(אכ הלכ))
        expect(types).to all(eq(:nonfinal_at_word_end))
      end
    end

    context 'when the word is quoted' do
      # The quotation marks are part of the scanned token, and must not be mistaken for the
      # gershayim of an acronym.
      let(:markdown) { "הוא אמר \"מלכ\" ברבים\n" }

      it 'still reports it' do
        expect(types).to eq([:nonfinal_at_word_end])
      end
    end

    context 'when the word is an abbreviation marked with a geresh' do
      let(:markdown) { "עמ' 12 וכו' ואילכ'\n" }

      it { is_expected.to be_empty }
    end

    context 'when the word is a one-letter prefix' do
      let(:markdown) { "מ עד ת\n" }

      it { is_expected.to be_empty }
    end

    context 'when the word ends in a proper final letter' do
      let(:markdown) { "אך הוא הלך הביתה\n" }

      it { is_expected.to be_empty }
    end

    context 'when the word is a loanword ending in pe' do
      # Final pe is /f/, so a word ending in a /p/ sound keeps the ordinary form
      let(:markdown) { "הוא שפך קטשופ על הצלחת\n" }

      it { is_expected.to be_empty }
    end

    context 'when the word is cut short by an adjacent dash or ellipsis' do
      let(:markdown) { "– לא, שמ–שנ–יה\n\n– המ... טבק טוב\n" }

      it { is_expected.to be_empty }
    end
  end

  describe 'paragraphs ending without punctuation' do
    let(:sentence) { (['אבגד הוזח טיכל מנסע פצקר שתאב גדהו זחטי'] * 4).join(' ') }

    context 'when a prose paragraph just stops' do
      let(:markdown) { "\n#{sentence}\n" }

      it 'reports it against the paragraph last line' do
        expect(findings).to contain_exactly(hash_including(type: :unterminated_paragraph, line: 2))
      end
    end

    context 'when the paragraph ends in a full stop' do
      let(:markdown) { "\n#{sentence}.\n" }

      it { is_expected.to be_empty }
    end

    context 'when the paragraph ends in punctuation inside a closing quotation mark' do
      let(:markdown) { "\n#{sentence} \"די!\"\n" }

      it { is_expected.to be_empty }
    end

    context 'when the paragraph ends in a dash, marking interrupted speech' do
      let(:markdown) { "\n#{sentence} —\n" }

      it { is_expected.to be_empty }
    end

    context 'when the paragraph is a heading' do
      let(:markdown) { "\n## #{sentence}\n" }

      it { is_expected.to be_empty }
    end

    context 'when the paragraph is shorter than a sentence' do
      let(:markdown) { "\nשלום עולם\n" }

      it { is_expected.to be_empty }
    end

    context 'when the genre is poetry' do
      let(:genre) { 'poetry' }
      let(:markdown) { "\n#{sentence}\n" }

      it 'does not apply the check at all' do
        expect(findings).to be_empty
      end
    end

    context 'when no genre is given' do
      let(:genre) { nil }
      let(:markdown) { "\n#{sentence}\n" }

      it { is_expected.to be_empty }
    end
  end

  describe 'general behaviour' do
    context 'when the markdown is blank' do
      let(:markdown) { nil }

      it { is_expected.to eq [] }
    end

    context 'when the text is clean' do
      let(:markdown) { "שלום עולם, מה שלומך?\n\nהכול בסדר גמור, תודה.\n" }

      it { is_expected.to be_empty }
    end

    context 'when a pointed letter is spelled as a presentation form' do
      # U+FB35 is a single codepoint for vav-with-dagesh; without normalization the word
      # would be scanned in two halves, and 'מחשכ' would look like a non-final ending.
      let(:markdown) { "או מחשכ\uFB35ת שררה שם\n" }

      it { is_expected.to be_empty }
    end

    context 'when line endings are CRLF' do
      let(:markdown) { "שורה ראשונה\r\nהוא נכנס לבי1ת\r\n" }

      it 'reports the correct line number' do
        expect(findings).to contain_exactly(hash_including(type: :digit_in_word, line: 2))
      end
    end

    context 'when one type recurs more times than the cap' do
      let(:markdown) { (["לבי1ת\n"] * (described_class::MAX_FINDINGS_PER_TYPE + 10)).join }

      it 'caps the findings for that type' do
        expect(types.count(:digit_in_word)).to eq described_class::MAX_FINDINGS_PER_TYPE
      end
    end
  end
end
