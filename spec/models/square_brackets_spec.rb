# frozen_string_literal: true

require 'rails_helper'
require 'rmultimarkdown'

RSpec.describe 'Square brackets in Markdown' do
  describe 'rendering plain square brackets' do
    it 'renders square brackets without escaping them' do
      markdown = '[מבוף מעל העיר]'
      html = MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8')
      
      expect(html).to include('[מבוף מעל העיר]')
      expect(html).not_to include('\[')
      expect(html).not_to include('\]')
    end

    it 'renders square brackets in Hebrew text correctly' do
      markdown = 'טקסט רגיל [מבוף מעל העיר] עוד טקסט'
      html = MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8')
      
      expect(html).to include('[מבוף מעל העיר]')
      expect(html).not_to include('\[')
      expect(html).not_to include('\]')
    end

    it 'still renders actual Markdown links correctly' do
      markdown = '[link text](http://example.com)'
      html = MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8')
      
      expect(html).to include('<a href="http://example.com">link text</a>')
    end

    it 'handles mixed content with both brackets and links' do
      markdown = 'טקסט [מבוף מעל העיר] וגם [קישור](http://example.com)'
      html = MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8')
      
      # Plain brackets should remain
      expect(html).to include('[מבוף מעל העיר]')
      # Link should be converted
      expect(html).to include('<a href="http://example.com">קישור</a>')
      # No escaped brackets
      expect(html).not_to include('\[')
      expect(html).not_to include('\]')
    end
  end

  describe 'HtmlFile characters method' do
    it 'does not escape square brackets in text content' do
      # Create a simple HTML that would be parsed
      html = '<html><body><p>[test brackets]</p></body></html>'
      
      doc = NokoDoc.new
      parser = Nokogiri::HTML::SAX::Parser.new(doc)
      parser.parse(html)
      
      # The markdown should contain unescaped brackets
      expect(doc.instance_variable_get(:@markdown)).to include('[test brackets]')
      expect(doc.instance_variable_get(:@markdown)).not_to include('\[test brackets\]')
    end
  end
end
