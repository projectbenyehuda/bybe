# frozen_string_literal: true

require 'rails_helper'

describe DetectFootnoteDiscrepancies do
  subject(:result) { described_class.call(markdown, **options) }

  let(:options) { {} }

  describe 'markdown with matching footnotes' do
    let(:markdown) { "טקסט עם הערה[^1] ועוד אחת[^2]\n\n[^1]: גוף ההערה\n[^2]: גוף ההערה השנייה\n" }

    it 'reports nothing' do
      expect(result).to eq(orphan_references: [], orphan_bodies: [])
    end
  end

  describe 'a reference with no body' do
    let(:markdown) { "טקסט עם הערה[^1] ועוד אחת[^2]\n\n[^1]: גוף ההערה\n" }

    it 'reports the reference as orphaned' do
      expect(result[:orphan_references]).to eq([{ id: '2', lines: [1], section: nil }])
      expect(result[:orphan_bodies]).to eq([])
    end
  end

  describe 'a body with no reference' do
    let(:markdown) { "טקסט עם הערה[^1]\n\n[^1]: גוף ההערה\n[^7]: גוף יתום\n" }

    it 'reports the body as orphaned' do
      expect(result[:orphan_bodies]).to eq([{ id: '7', lines: [4], section: nil }])
      expect(result[:orphan_references]).to eq([])
    end
  end

  describe 'a reference repeated on several lines' do
    let(:markdown) { "ראשון[^a]\nשני[^a]\n" }

    it 'reports one entry listing every line' do
      expect(result[:orphan_references]).to eq([{ id: 'a', lines: [1, 2], section: nil }])
    end
  end

  describe 'the same reference twice on one line' do
    let(:markdown) { "טקסט עם הפניה כפולה[^9][^9]\n" }

    it 'reports that line once' do
      expect(result[:orphan_references]).to eq([{ id: '9', lines: [1], section: nil }])
    end
  end

  describe 'a footnote body that itself contains a reference' do
    let(:markdown) { "טקסט[^1]\n\n[^1]: גוף ההערה המפנה להערה אחרת[^2]\n" }

    it 'treats the marker as a body and the bracket inside it as a reference' do
      expect(result[:orphan_references]).to eq([{ id: '2', lines: [3], section: nil }])
      expect(result[:orphan_bodies]).to eq([])
    end
  end

  describe 'a body marker indented by up to three spaces, as MultiMarkdown allows' do
    let(:markdown) { "טקסט[^1]\n\n   [^1]: גוף ההערה\n" }

    it 'recognises it as a body' do
      expect(result).to eq(orphan_references: [], orphan_bodies: [])
    end
  end

  describe 'a body marker indented by four spaces, which MultiMarkdown reads as a code block' do
    let(:markdown) { "טקסט[^1]\n\n    [^1]: גוף ההערה\n" }

    it 'counts it as a reference rather than a body' do
      expect(result[:orphan_references]).to eq([{ id: '1', lines: [1, 3], section: nil }])
      expect(result[:orphan_bodies]).to eq([])
    end
  end

  describe 'an inline footnote whose identifier is a whole sentence' do
    let(:markdown) { "טקסט[^הערה שלמה בתוך הסוגריים]\n" }

    it 'is reported, since it has no body' do
      expect(result[:orphan_references]).to eq(
        [{ id: 'הערה שלמה בתוך הסוגריים', lines: [1], section: nil }]
      )
    end
  end

  describe 'blank markdown' do
    let(:markdown) { nil }

    it 'reports nothing' do
      expect(result).to eq(orphan_references: [], orphan_bodies: [])
    end
  end

  describe 'markdown split into works by &&& separators' do
    let(:options) { { split_on_sections: true } }
    let(:markdown) do
      "&&& יצירה ראשונה\nטקסט[^1]\n\n&&& יצירה שנייה\nטקסט אחר\n\n[^1]: גוף ההערה\n"
    end

    it 'does not let a reference match a body in another work' do
      expect(result[:orphan_references]).to eq([{ id: '1', lines: [2], section: 'יצירה ראשונה' }])
      expect(result[:orphan_bodies]).to eq([{ id: '1', lines: [7], section: 'יצירה שנייה' }])
    end

    context 'when reference and body sit in the same work' do
      let(:markdown) { "&&& יצירה ראשונה\nטקסט[^1]\n\n[^1]: גוף ההערה\n\n&&& יצירה שנייה\nטקסט אחר\n" }

      it 'reports nothing' do
        expect(result).to eq(orphan_references: [], orphan_bodies: [])
      end
    end

    context 'when the same markdown is scanned as a single document' do
      let(:options) { { split_on_sections: false } }
      let(:markdown) do
        "&&& יצירה ראשונה\nטקסט[^1]\n\n&&& יצירה שנייה\nטקסט אחר\n\n[^1]: גוף ההערה\n"
      end

      it 'matches across the separators' do
        expect(result).to eq(orphan_references: [], orphan_bodies: [])
      end
    end

    context 'when text precedes the first separator' do
      let(:markdown) { "פתיח[^1]\n\n&&& יצירה ראשונה\nטקסט\n" }

      it 'scans that leading text as its own untitled section' do
        expect(result[:orphan_references]).to eq([{ id: '1', lines: [1], section: nil }])
      end
    end
  end
end
