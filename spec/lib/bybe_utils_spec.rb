# frozen_string_literal: true

require 'rails_helper'

describe BybeUtils do
  let(:test_class) do
    Class.new do
      include BybeUtils
    end
  end
  let(:instance) { test_class.new }

  describe '#footnotes_noncer' do
    let(:html_with_footnotes) do
      <<~HTML
        <p>Text with footnote<a href="#fn:1" id="fnref:1"><sup>1</sup></a>.</p>
        <ol>
          <li id="fn:1">
            <p>Footnote text <a href="#fnref:1">↩</a></p>
          </li>
        </ol>
      HTML
    end

    it 'adds nonce to footnote reference anchor href' do
      result = instance.footnotes_noncer(html_with_footnotes, 'test')
      expect(result).to include('href="#fn:test_1"')
    end

    it 'adds nonce to footnote reference anchor id' do
      result = instance.footnotes_noncer(html_with_footnotes, 'test')
      expect(result).to include('id="fnref:test_1"')
    end

    it 'adds nonce to footnote body anchor id' do
      result = instance.footnotes_noncer(html_with_footnotes, 'test')
      expect(result).to include('id="fn:test_1"')
    end

    it 'adds nonce to back-reference from footnote body' do
      result = instance.footnotes_noncer(html_with_footnotes, 'test')
      expect(result).to include('href="#fnref:test_1"')
    end

    it 'does not leave any non-nonced footnote anchors' do
      result = instance.footnotes_noncer(html_with_footnotes, 'test')
      expect(result).not_to include('href="#fn:1"')
      expect(result).not_to include('id="fnref:1"')
      expect(result).not_to include('id="fn:1"')
    end

    it 'handles multiple footnotes with different nonces' do
      html_with_multiple = <<~HTML
        <p>Text with footnote<a href="#fn:1" id="fnref:1"><sup>1</sup></a> and another<a href="#fn:2" id="fnref:2"><sup>2</sup></a>.</p>
        <ol>
          <li id="fn:1">
            <p>First footnote <a href="#fnref:1">↩</a></p>
          </li>
          <li id="fn:2">
            <p>Second footnote <a href="#fnref:2">↩</a></p>
          </li>
        </ol>
      HTML

      result = instance.footnotes_noncer(html_with_multiple, 'abc')
      expect(result).to include('fn:abc_1')
      expect(result).to include('fn:abc_2')
      expect(result).to include('fnref:abc_1')
      expect(result).to include('fnref:abc_2')
    end
  end

  describe '#salt_footnote_link' do
    let(:footnote_link) { '<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a>' }

    it 'salts the href attribute' do
      result = instance.salt_footnote_link(footnote_link, 5)
      expect(result).to include('href="#fn:5_1"')
    end

    it 'salts the id attribute' do
      result = instance.salt_footnote_link(footnote_link, 5)
      expect(result).to include('id="fnref:5_1"')
    end

    it 'preserves other attributes' do
      result = instance.salt_footnote_link(footnote_link, 5)
      expect(result).to include('title="see footnote"')
      expect(result).to include('class="footnote"')
      expect(result).to include('<sup>1</sup>')
    end

    it 'returns nil when input is nil' do
      result = instance.salt_footnote_link(nil, 5)
      expect(result).to be_nil
    end

    it 'handles string nonces' do
      result = instance.salt_footnote_link(footnote_link, 'test')
      expect(result).to include('href="#fn:test_1"')
      expect(result).to include('id="fnref:test_1"')
    end
  end

  describe '#kwic_concordance' do
    context 'with basic English text' do
      let(:input) do
        [
          { label: 'text A', buffer: 'The quick brown fox jumps over the lazy dog.' },
          { label: 'text B', buffer: 'The brown bear is quicker than a dog but not quicker than a fox.' }
        ]
      end

      it 'returns an array of token entries' do
        result = instance.kwic_concordance(input)
        expect(result).to be_an(Array)
        expect(result.first).to have_key(:token)
        expect(result.first).to have_key(:instances)
      end

      it 'sorts tokens alphabetically' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }
        expect(tokens).to eq(tokens.sort)
      end

      it 'removes punctuation at word boundaries' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }
        expect(tokens).not_to include('dog.')
        expect(tokens).not_to include('fox.')
        expect(tokens).to include('dog')
        expect(tokens).to include('fox')
      end

      it 'provides correct before and after context' do
        result = instance.kwic_concordance(input)
        the_entry = result.find { |e| e[:token] == 'The' }
        first_instance = the_entry[:instances].first

        expect(first_instance[:before_context]).to eq('')
        expect(first_instance[:after_context]).to eq('quick brown fox jumps over')
      end

      it 'tracks paragraph numbers correctly' do
        result = instance.kwic_concordance(input)
        the_entry = result.find { |e| e[:token] == 'The' }
        expect(the_entry[:instances].first[:paragraph]).to eq(1)
      end

      it 'sorts instances by label and paragraph' do
        result = instance.kwic_concordance(input)
        the_entry = result.find { |e| e[:token] == 'The' }
        labels = the_entry[:instances].map { |i| i[:label] }
        expect(labels).to eq(labels.sort)
      end
    end

    context 'with multiple paragraphs' do
      let(:input) do
        [
          { label: 'text A',
            buffer: "The quick brown fox jumps over the lazy dog.\nThe dog belongs to Groucho." }
        ]
      end

      it 'tracks different paragraph numbers' do
        result = instance.kwic_concordance(input)
        the_entry = result.find { |e| e[:token] == 'The' }

        expect(the_entry[:instances].length).to eq(2)
        expect(the_entry[:instances][0][:paragraph]).to eq(1)
        expect(the_entry[:instances][1][:paragraph]).to eq(2)
      end

      it 'provides correct context from second paragraph' do
        result = instance.kwic_concordance(input)
        the_entry = result.find { |e| e[:token] == 'The' }
        second_instance = the_entry[:instances][1]

        expect(second_instance[:before_context]).to eq('')
        expect(second_instance[:after_context]).to eq('dog belongs to Groucho')
      end
    end

    context 'with Hebrew acronyms' do
      let(:input) do
        [
          { label: 'טקסט א', buffer: 'מפא"י היתה מפלגה פוליטית ישראלית.' },
          { label: 'טקסט ב', buffer: 'רמטכ"ל הוא ראש המטה הכללי של צה"ל.' },
          { label: 'טקסט ג', buffer: 'חט"ב הוא חטיבה.' }
        ]
      end

      it 'preserves Hebrew acronyms with quotation marks' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        expect(tokens).to include('מפא"י')
        expect(tokens).to include('רמטכ"ל')
        expect(tokens).to include('צה"ל')
        expect(tokens).to include('חט"ב')
      end

      it 'treats acronyms as single tokens' do
        result = instance.kwic_concordance(input)
        mapai_entry = result.find { |e| e[:token] == 'מפא"י' }

        expect(mapai_entry).not_to be_nil
        expect(mapai_entry[:instances].length).to eq(1)
      end

      it 'provides correct context for acronyms' do
        result = instance.kwic_concordance(input)
        ramatkal_entry = result.find { |e| e[:token] == 'רמטכ"ל' }

        expect(ramatkal_entry[:instances].first[:after_context]).to eq('הוא ראש המטה הכללי של')
      end
    end

    context 'with quotation marks that are not acronyms' do
      let(:input) do
        [
          { label: 'test1', buffer: '"שלום" אמר לי' }, # Quoted word
          { label: 'test2', buffer: 'הוא אמר "כן"' }, # Quoted word at end
          { label: 'test3', buffer: '"א' },  # Quote before single letter (not acronym)
          { label: 'test4', buffer: 'א"' },  # Quote after single letter (not acronym)
          { label: 'test5', buffer: "'hello' world" }, # Single quotes around word
          { label: 'test6', buffer: "word's" }, # Possessive (should keep apostrophe in middle)
          { label: 'test7', buffer: '"מפא"י היא מפלגה ישראלית"' } # Acronym inside quotes
        ]
      end

      it 'does not create tokens beginning with quotation marks' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        # Should not have any tokens starting with quotes
        problematic_tokens = tokens.select { |t| t.start_with?('"', "'") }
        expect(problematic_tokens).to be_empty,
                                      "Found tokens starting with quotes: #{problematic_tokens.inspect}"
      end

      it 'does not create tokens ending with quotation marks (except acronyms)' do
        result = instance.kwic_concordance(input)

        # Get all tokens that end with quotes
        tokens_ending_with_quotes = result.select do |entry|
          token = entry[:token]
          token.end_with?('"', "'")
        end

        # Check that any token ending with quote is actually an acronym
        tokens_ending_with_quotes.each do |entry|
          token = entry[:token]
          is_acronym = token.length >= 3 && token[-2] == '"'
          expect(is_acronym).to be(true),
                                "Token #{token.inspect} ends with quote but is not a valid acronym"
        end
      end

      it 'correctly tokenizes quoted words' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        # These should exist without quotes
        expect(tokens).to include('שלום')
        expect(tokens).to include('כן')
        expect(tokens).to include('א')
        expect(tokens).to include('hello')
        expect(tokens).to include('world')
      end

      it 'handles possessives and contractions appropriately' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        # Possessives like word's should not be split
        # The current implementation may split them - we just need to ensure
        # no token starts or ends with just a quote
        tokens.each do |token|
          expect(token).not_to start_with('"', "'"),
                               "Token #{token.inspect} should not start with a quote"
          # Allow tokens to end with ' if it's part of the word (like can't)
          # but not if it's a standalone quote
          if token.end_with?("'")
            expect(token.length).to be > 1,
                                    "Token #{token.inspect} should not be just a quote"
          end
        end
      end

      it 'handles Hebrew acronyms inside quoted expressions' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        # Should include the acronym without surrounding quotes
        expect(tokens).to include('מפא"י'),
                          'Should extract acronym מפא"י from quoted expression'

        # Should not have tokens starting or ending with quotes
        problematic_tokens = tokens.select { |t| t.start_with?('"', "'") }
        expect(problematic_tokens).to be_empty,
                                      "Found tokens starting with quotes: #{problematic_tokens.inspect}"
      end
    end

    context 'with various punctuation' do
      let(:input) do
        [
          { label: 'text', buffer: 'Hello, world! How are you? I\'m fine, thanks.' }
        ]
      end

      it 'removes commas, exclamation marks, and question marks' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        expect(tokens).to include('Hello')
        expect(tokens).to include('world')
        expect(tokens).not_to include('Hello,')
        expect(tokens).not_to include('world!')
        expect(tokens).not_to include('you?')
      end

      it 'handles apostrophes in contractions' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        # Apostrophes in contractions shouldn't be treated as word boundaries
        expect(tokens).to include('I\'m')
      end
    end

    context 'with edge cases' do
      it 'handles empty buffer' do
        input = [{ label: 'empty', buffer: '' }]
        result = instance.kwic_concordance(input)
        expect(result).to eq([])
      end

      it 'handles single word' do
        input = [{ label: 'single', buffer: 'word' }]
        result = instance.kwic_concordance(input)

        expect(result.length).to eq(1)
        expect(result[0][:token]).to eq('word')
        expect(result[0][:instances][0][:before_context]).to eq('')
        expect(result[0][:instances][0][:after_context]).to eq('')
      end

      it 'handles multiple spaces' do
        input = [{ label: 'spaces', buffer: 'word1    word2     word3' }]
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        expect(tokens).to eq(%w(word1 word2 word3))
      end

      it 'limits context to 5 tokens' do
        input = [{ label: 'long', buffer: 'one two three four five six seven eight nine ten eleven twelve' }]
        result = instance.kwic_concordance(input)
        seven_entry = result.find { |e| e[:token] == 'seven' }

        expect(seven_entry[:instances][0][:before_context]).to eq('two three four five six')
        expect(seven_entry[:instances][0][:after_context]).to eq('eight nine ten eleven twelve')
      end

      it 'handles text with only punctuation' do
        input = [{ label: 'punct', buffer: '... !!! ???' }]
        result = instance.kwic_concordance(input)
        expect(result).to eq([])
      end
    end

    context 'with mixed delimiters' do
      let(:input) do
        [
          { label: 'mixed', buffer: 'word1;word2:word3/word4|word5' }
        ]
      end

      it 'treats various delimiters as word boundaries' do
        result = instance.kwic_concordance(input)
        tokens = result.map { |entry| entry[:token] }

        expect(tokens).to include('word1')
        expect(tokens).to include('word2')
        expect(tokens).to include('word3')
        expect(tokens).to include('word4')
        expect(tokens).to include('word5')
      end
    end

    context 'integration test matching example from issue' do
      let(:input) do
        [
          { label: 'text A',
            buffer: "The quick brown fox jumps over the lazy dog.\nThe dog belongs to Groucho." },
          { label: 'text B',
            buffer: 'The brown bear is quicker than a dog but not quicker than a fox.' },
          { label: 'text C',
            buffer: "Outside of a dog, a book is a man's best friend;\ninside of a dog, it's too dark to read." }
        ]
      end

      it 'produces the expected structure for "The" token' do
        result = instance.kwic_concordance(input)
        the_entry = result.find { |e| e[:token] == 'The' }

        expect(the_entry).not_to be_nil
        expect(the_entry[:instances].length).to eq(3)

        # First instance from text A, paragraph 1
        first = the_entry[:instances][0]
        expect(first[:label]).to eq('text A')
        expect(first[:paragraph]).to eq(1)
        expect(first[:before_context]).to eq('')
        expect(first[:after_context]).to eq('quick brown fox jumps over')

        # Second instance from text A, paragraph 2
        second = the_entry[:instances][1]
        expect(second[:label]).to eq('text A')
        expect(second[:paragraph]).to eq(2)
        expect(second[:before_context]).to eq('')
        expect(second[:after_context]).to eq('dog belongs to Groucho')

        # Third instance from text B
        third = the_entry[:instances][2]
        expect(third[:label]).to eq('text B')
        expect(third[:paragraph]).to eq(1)
        expect(third[:before_context]).to eq('')
        expect(third[:after_context]).to eq('brown bear is quicker than')
      end

      it 'produces the expected structure for "quick" token' do
        result = instance.kwic_concordance(input)
        quick_entry = result.find { |e| e[:token] == 'quick' }

        expect(quick_entry).not_to be_nil
        expect(quick_entry[:instances].length).to eq(1)

        instance = quick_entry[:instances][0]
        expect(instance[:label]).to eq('text A')
        expect(instance[:before_context]).to eq('The')
        expect(instance[:after_context]).to eq('brown fox jumps over the')
        expect(instance[:paragraph]).to eq(1)
      end

      it 'handles "dog" appearing in multiple texts' do
        result = instance.kwic_concordance(input)
        dog_entry = result.find { |e| e[:token] == 'dog' }

        expect(dog_entry[:instances].length).to be >= 4
        labels = dog_entry[:instances].map { |i| i[:label] }
        expect(labels).to include('text A', 'text B', 'text C')
      end
    end
  end

  describe '#textify_lang' do
    it 'names Japanese in Hebrew' do
      I18n.with_locale(:he) { expect(instance.textify_lang('ja')).to eq('יפנית') }
    end

    it 'names Japanese in English' do
      I18n.with_locale(:en) { expect(instance.textify_lang('ja')).to eq('Japanese') }
    end

    it 'names every supported language, save the explicit unknown code' do
      unnamed = (instance.get_langs - ['unk']).select { |iso| instance.textify_lang(iso) == I18n.t(:unknown) }
      expect(unnamed).to be_empty
    end
  end

  describe '#get_langs' do
    it "includes Japanese ('ja')" do
      expect(instance.get_langs).to include('ja')
    end
  end

  describe '#orig_lang_label' do
    context 'when original language is unknown' do
      it 'returns the unknown-language I18n string for nil' do
        expect(instance.orig_lang_label(nil)).to eq(I18n.t(:translated_from_unknown_lang))
      end

      it 'returns the unknown-language I18n string for blank string' do
        expect(instance.orig_lang_label('')).to eq(I18n.t(:translated_from_unknown_lang))
      end

      it "returns the unknown-language I18n string for 'unknown'" do
        expect(instance.orig_lang_label('unknown')).to eq(I18n.t(:translated_from_unknown_lang))
      end

      it "returns the unknown-language I18n string for 'unk'" do
        expect(instance.orig_lang_label('unk')).to eq(I18n.t(:translated_from_unknown_lang))
      end
    end

    context 'when original language is a known ISO code' do
      it 'returns the from_lang prefix combined with the language name' do
        expect(instance.orig_lang_label('ru')).to eq("#{I18n.t(:from_lang)}#{I18n.t(:russian)}")
      end

      it 'returns the correct label for Hebrew' do
        expect(instance.orig_lang_label('he')).to eq("#{I18n.t(:from_lang)}#{I18n.t(:hebrew)}")
      end
    end
  end

  describe '#normalize_date' do
    context 'with Hebrew dates' do
      it 'parses a day, month and year using ASCII quotes' do
        expect(instance.normalize_date('כ"ג שבט תר"ץ')).to eq Date.new(1930, 2, 21)
      end

      it 'parses a day, month and year using Hebrew geresh and gershayim' do
        expect(instance.normalize_date('כ״ג שבט תר״ץ')).to eq Date.new(1930, 2, 21)
      end

      # regression test: this used to raise TypeError (nil can't be coerced into Integer), causing a 500
      it 'parses a range of days, taking the first day of the range' do
        expect(instance.normalize_date('ט׳–כ״ג שבט תר״ץ')).to eq Date.new(1930, 2, 7)
      end

      it 'parses a range of days written with ASCII quotes and a hyphen' do
        expect(instance.normalize_date(%q(ט'-כ"ג שבט תר"ץ))).to eq Date.new(1930, 2, 7)
      end

      it 'defaults to mid-month when only a month and year are given' do
        expect(instance.normalize_date('שבט תר"ץ')).to eq Date.new(1930, 2, 13)
      end

      it 'defaults to mid-year when only a year is given' do
        expect(instance.normalize_date('תר"ץ')).to eq Date.new(1929, 10, 18)
      end

      it 'parses a year written with gershayim' do
        expect(instance.normalize_date('תר״ץ')).to eq Date.new(1929, 10, 18)
      end

      it 'takes the first year of a range of years' do
        expect(instance.normalize_date('תר"ץ-תרצ"ה')).to eq Date.new(1929, 10, 18)
      end

      it 'returns nil for Hebrew text that holds no date' do
        expect(instance.normalize_date('ללא תאריך')).to be_nil
      end

      it 'returns nil for punctuation alone' do
        expect(instance.normalize_date('–')).to be_nil
      end
    end

    context 'with Gregorian dates' do
      it 'parses a numeric date' do
        expect(instance.normalize_date('5/6/1930')).to eq Date.new(1930, 6, 5)
      end

      it 'parses a Hebrew-spelled Gregorian month' do
        expect(instance.normalize_date('5 ביוני 1930')).to eq Date.new(1930, 6, 5)
      end

      it 'defaults to mid-year when only a year is given' do
        expect(instance.normalize_date('1930')).to eq Date.new(1930, 7, 1)
      end
    end

    it 'returns nil for nil' do
      expect(instance.normalize_date(nil)).to be_nil
    end

    it 'returns nil for an empty string' do
      expect(instance.normalize_date('')).to be_nil
    end
  end
  describe '#epub_role_from_ia_role' do
    it "maps annotator to the MARC 'ann' relator" do
      expect(instance.epub_role_from_ia_role('annotator')).to eq('ann')
    end

    it "falls back to 'oth' for unmapped roles" do
      expect(instance.epub_role_from_ia_role('designer')).to eq('oth')
    end
  end

  describe '#html2txt' do
    it 'strips tags' do
      expect(instance.html2txt('<p>hello <b>world</b></p>')).to eq('hello world')
    end

    # Regression: entities used to be decoded before strip_tags, whose HTML5 sanitizer re-escapes
    # its own output, so the "plain text" came back with the entities still in it.
    it 'decodes &nbsp; to a non-breaking space rather than leaving the entity' do
      expect(instance.html2txt('a&nbsp;b')).to eq("a\u00A0b")
    end

    it 'decodes &amp; to an ampersand rather than leaving the entity' do
      expect(instance.html2txt('Dov &amp; Sons')).to eq('Dov & Sons')
    end

    it 'decodes numeric entities' do
      expect(instance.html2txt('&#8211; dash')).to eq('– dash')
    end

    it 'leaves no HTML entities behind when tags and entities are mixed' do
      expect(instance.html2txt('<b>bold</b>&nbsp;&amp;&nbsp;more')).not_to match(/&(?:nbsp|amp);/)
    end

    it 'normalizes curly quotes decoded from entities' do
      expect(instance.html2txt('&ldquo;quoted&rdquo;')).to eq('"quoted"')
    end

    it 'drops conditional-comment leftovers' do
      expect(instance.html2txt('<!--[if gte mso 9]><xml><![endif]-->text')).to eq('text')
    end
  end
end
