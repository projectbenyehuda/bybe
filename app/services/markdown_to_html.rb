# frozen_string_literal: true

# Converts markdown to HTML
class MarkdownToHtml < ApplicationService
  def call(markdown)
    return '' if markdown.blank?

    # remove MMD's automatic figcaptions
    html = MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8')
                        .gsub(%r{<figcaption>.*?</figcaption>}, '')
                        .gsub('<table>', '<div style="overflow-x:auto;"><table>')
                        .gsub('</table>', '</table></div>')
    html.gsub!(%r{(<li id="fn:\d+"[^>]*>\s*)<p>(.*?)</p>}) do
      # Change first <p> element in footnotes to <span> to prevent line break
      "#{::Regexp.last_match(1)}<span>#{::Regexp.last_match(2)}</span>"
    end
    # Add target="_blank" to external links (not internal anchor links starting with #)
    html.gsub!(/<a\s+([^>]*?)>/) do
      attributes = ::Regexp.last_match(1)
      # Skip if: no href attribute, internal anchor links (href="#..."), or already has target attribute
      if !attributes.match?(/\bhref=/) || attributes.match?(/\bhref="#/) || attributes.match?(/\btarget=/)
        "<a #{attributes}>"
      else
        "<a #{attributes} target=\"_blank\">"
      end
    end
    html
  end
end
