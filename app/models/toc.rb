require 'htmlentities'
require 'erb'

class Toc < ApplicationRecord
  has_paper_trail
  enum :status, { raw: 0, ready: 1, deprecated: 2 }
  before_save :update_cached_toc

  def refresh_links
    buf = toc
    ret = ''
    until buf.empty?
      m = buf.match(/&&&\s*פריט: (.\d+)\s*&&&\s*כותרת: (.*?)&&&/)
      if m.nil?
        ret += buf
        buf = ''
      else
        ret += ::Regexp.last_match.pre_match
        addition = ::Regexp.last_match(0) # by default
        buf = ::Regexp.last_match.post_match
        if ::Regexp.last_match(1)[0] == 'ה' # linking to a legacy HtmlFile
          begin
            h = HtmlFile.find_by(id: ::Regexp.last_match(1)[1..-1].to_i)
            if !h.nil? && (h.status == 'Published' && h.manifestations.count > 0)
              addition = "&&& פריט: מ#{h.manifestations[0].id} &&& כותרת: #{::Regexp.last_match(2)} &&&" # else, no manifestation yet, keep linking to the HtmlFile
            end
          rescue StandardError
            puts 'no such HtmlFile'
          end
        end
        ret += addition
      end
    end
    return ret
  end

  def linked_item_ids
    return toc.scan(/&&&\s*פריט: מ(\d+)\s*&&&\s*כותרת: .*?&&&/m).map { |x| x[0].to_i }.uniq
  end

  def linked_items
    return Manifestation.find(linked_item_ids)
  end

  def structure_okay?
    sections = toc.scan(/^## (.*)\s*$/)
    return false if sections.empty?

    # get_genres returns ['poetry', 'prose', 'drama', 'fables','article', 'memoir', 'letters', 'reference', 'lexicon']
    last_encountered = 0
    translations_encountered = false
    sections.each do |sect|
      genre = identify_genre_by_heading(sect[0].strip)
      return false if genre.nil?

      i = get_genres.find_index(genre)
      if i.nil?
        return false unless genre == 'translations'

        translations_encountered = true

      else
        return false if i < last_encountered || translations_encountered

        last_encountered = i
      end
    end
    return true
  end

  def update_cached_toc
    self.cached_toc = toc_links_to_markdown_links(toc)
  end

  protected

  def toc_links_to_markdown_links(buf)
    ret = ''
    coder = HTMLEntities.new
    until buf.empty?
      m = buf.match(/&&&\s*פריט: (\S\d+)\s*&&&\s*כותרת: (.*?)\s*&&&/) # tolerate whitespace; this will be edited manually
      if m.nil?
        ret += buf
        buf = ''
      else
        ret += ::Regexp.last_match.pre_match
        addition = ::Regexp.last_match(0) # by default
        buf = ::Regexp.last_match.post_match
        item = ::Regexp.last_match(1)
        # Use basic HTML entity encoding for all characters to ensure safety
        anchor_name = coder.encode(::Regexp.last_match(2), :named)
        if item[0] == 'ה' # linking to a legacy HtmlFile
          h = HtmlFile.find_by(id: item[1..-1].to_i)
          unless h.nil?
            # Use HTML link format to avoid issues with square brackets in anchor text
            # Escape both the URL and anchor name for security
            escaped_url = ERB::Util.html_escape(h.url)
            addition = "<a href=\"#{escaped_url}\">#{anchor_name}</a>"
          end
        else # manifestation
          begin
            mft = Manifestation.find(item[1..-1].to_i)
            unless mft.nil?
              # Use HTML link format to avoid issues with square brackets in anchor text
              url = Rails.application.routes.url_helpers.url_for(controller: :manifestation, action: :read, id: mft.id)
              # Escape both the URL and anchor name for security
              escaped_url = ERB::Util.html_escape(url)
              addition = "<a href=\"#{escaped_url}\">#{anchor_name}</a>"
            end
          rescue StandardError
            Rails.logger.info("Manifestation not found: #{item[1..-1].to_i}!")
          end
        end
        ret += addition
      end
    end
    return ret
  end
end
