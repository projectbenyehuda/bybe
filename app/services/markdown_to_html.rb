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
    html
  end
end
