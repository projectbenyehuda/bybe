# frozen_string_literal: true

class LegacyLexiconShimController < ApplicationController
  LEGACY_URL = 'https://benyehuda.org/lexicon/'
  def index
    request_url = if params['path'].present?
                    "#{LEGACY_URL}#{params['path']}.#{params['format'] || ''}"
                  else
                    "#{LEGACY_URL}"
                  end

    # Make the request to the legacy lexicon using HTTPS and Net
    blog_html = Net::HTTP.get(URI(request_url))
    render html: rewrite_links(blog_html)
  end

  private

  # rewrite relative links to point to the new lexicon paths
  def rewrite_links(html_content)
    doc = Nokogiri::HTML(html_content)

    # Rewrite anchor tags
    doc.css('a').each do |link|
      href = link['href']
      next unless href
      next if href.start_with?('http://', 'https://', '#', 'mailto:')

      unless href.start_with?('/lexicon/')
        link['href'] = "/lexicon/#{href}"
      end
    end

    # Rewrite form actions
    doc.css('form').each do |form|
      action = form['action']
      next unless action
      next if action.start_with?('http://', 'https://', '#', 'mailto:')

      unless action.start_with?('/lexicon/')
        form['action'] = "/lexicon/#{action}"
      end
    end

    # rewrite img src attributes
    doc.css('img').each do |img|
      src = img['src']
      next unless src
      next if src.start_with?('http://', 'https://', '#', 'mailto:')

      unless src.start_with?('/lexicon/')
        img['src'] = "/lexicon/#{src}"
      end
    end

    doc.to_html.html_safe
  end
end
