# frozen_string_literal: true

# Converts markdown to HTML
class MarkdownToHtml < ApplicationService
  def call(markdown)
    return '' if markdown.blank?

    # remove MMD's automatic figcaptions
    html = MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8')
                        .gsub(%r{<figcaption>.*?</figcaption>}, '')
                        .gsub('<table', '<div style="overflow-x:auto;"><table')
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
    add_footnote_popovers(html)
  end

  private

  # Decorates footnote reference links (e.g. <a href="#fn:1" class="footnote">) with
  # Bootstrap popover data attributes carrying the footnote body HTML, so readers can
  # see the footnote inline without jumping to the bottom of the document.
  # Only the reference <a> tags are rewritten; everything else is preserved byte-for-byte.
  def add_footnote_popovers(html)
    return html unless html.include?('class="footnote"') && html.include?('id="fn:')

    contents_by_id = footnote_contents_by_id(html)
    return html if contents_by_id.empty?

    html.gsub(/<a\s+([^>]*?\bclass="footnote"[^>]*?)>/) do
      attrs = ::Regexp.last_match(1)
      match = attrs.match(/\bhref="#(fn:\d+)"/)
      content = match && contents_by_id[match[1]]
      if content.blank?
        "<a #{attrs}>"
      else
        fn_id = match[1]
        # Bootstrap would use the title attribute as the popover header; strip it so
        # the popover shows only the footnote body.
        stripped = attrs.sub(/\s*\btitle="[^"]*"/, '')
        popover_attrs = 'tabindex="0" data-toggle="popover" data-trigger="focus" data-html="true"'
        full_content = "#{content}#{footnote_popover_footer(fn_id)}"
        %(<a #{stripped} #{popover_attrs} data-content="#{CGI.escapeHTML(full_content)}">)
      end
    end
  end

  def footnote_popover_footer(fn_id)
    %(<div class="mt-2 pt-1 border-top"><a href="##{fn_id}">#{I18n.t(:footnote_popover_jump_link)}</a> ) +
      %(<a href="#" class="fn-popover-close" aria-label="#{I18n.t(:footnote_popover_close)}">[x]</a></div>)
  end

  # Builds { "fn:1" => "<inner html without reverse link>", ... } from the footnote list.
  def footnote_contents_by_id(html)
    {}.tap do |hash|
      html.scan(%r{<li id="(fn:\d+)"[^>]*>(.*?)</li>}m) do |id, inner|
        cleaned = inner.gsub(%r{\s*<a[^>]*class="reversefootnote"[^>]*>.*?</a>}m, '').strip
        hash[id] = cleaned unless cleaned.empty?
      end
    end
  end
end
