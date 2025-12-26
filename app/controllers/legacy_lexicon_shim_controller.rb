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
    uri = URI(request_url)
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      body = response.body
      content_type = response['content-type'] || 'application/octet-stream'

      # Only run HTML rewriting for HTML responses; proxy other assets with correct content-type
      if content_type.include?('text/html')
        render html: rewrite_links(body)
      else
        send_data body, type: content_type, disposition: 'inline'
      end
    else
      render plain: 'Legacy resource not available', status: response.code.to_i
    end
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
