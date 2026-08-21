# frozen_string_literal: true

# Some php documents contain links to authority page on BenYehuda website
# If such link is present we need to extract an authority_id from it and remove the link from the document
module Lexicon
  class ExtractAuthority < ApplicationService
    def call(html_doc)
      # Link to authority includes image badge so we look for it
      # NOTE: in source PHP img url is "00000_files/Ben-Yehuda-s.jpg" but we replace it with "/lex/Ben-Yehuda-s.jpg"
      # during preprocessing in AttachImages service
      img = html_doc.at_css('img[src="/lex/Ben-Yehuda-s.jpg"]')
      return nil if img.nil?

      # img element should be wrapped into an anchor tag
      node = img.parent
      return nil unless node.name == 'a'

      link = node['href']&.downcase&.strip
      match = link.match(%r{\Ahttps?://(www\.)?benyehuda\.org/author/(?<authority_id>\d+)})
      return nil unless match

      # Usually anchor tag should be wrapped in a td tag
      if node.parent.name == 'td'
        node = node.parent
      end

      # remove anchor tag with wrapping td (if present)
      node.remove

      # Returning authority_id from the link
      authority_id = match[:authority_id]
      return Authority.find_by(id: authority_id)
    end
  end
end
