# frozen_string_literal: true

module Lexicon
  # Service to associate a LexPerson with an existing Authority record.
  #
  # Tries three methods in order:
  # 1. Links to benyehuda.org in the PHP file - numeric ID extracted directly,
  #    string slug looked up via HtmlDir (same logic as html_file#render_by_legacy_url)
  # 2. Wikidata item linked in the PHP file - P7507 property (Project Ben-Yehuda author ID)
  #    fetched from the Wikidata REST API
  # 3. Name match - if exactly one Authority matches the entry title, associate it
  #
  # Sets lex_person.authority and saves if an authority is found.
  class AssociateAuthority < ApplicationService
    BENYEHUDA_HOST_PATTERN = %r{\Ahttps?://(?:www\.)?benyehuda\.org}i
    WIKIDATA_ENTITY_PATTERN = %r{wikidata\.org/(?:wiki|entity)/(Q\d+)}i
    WIKIDATA_API_BASE = 'https://www.wikidata.org'
    # P7507 = Project Ben-Yehuda author ID property on Wikidata
    WIKIDATA_PBY_PROPERTY = 'P7507'

    def call(lex_person, html_doc)
      authority = find_by_benyehuda_link(html_doc) ||
                  find_by_wikidata(html_doc) ||
                  find_by_name(lex_person)

      return lex_person if authority.nil?

      lex_person.authority = authority
      lex_person.save!
      lex_person
    end

    private

    def find_by_benyehuda_link(html_doc)
      html_doc.css('a[href]').each do |link|
        href = link['href'].to_s
        next unless href.match?(BENYEHUDA_HOST_PATTERN)

        begin
          path = URI.parse(href).path
        rescue URI::InvalidURIError
          next
        end

        next if path.blank?

        authority = authority_from_benyehuda_path(path)
        return authority if authority
      end

      nil
    end

    # Emulates what HtmlFileController#render_by_legacy_url does to resolve a path to an Authority.
    def authority_from_benyehuda_path(path)
      # Numeric ID: /author/1234 or /author/1234/
      if (match = path.match(%r{\A/author/(\d+)/?\z}))
        return Authority.find_by(id: match[1].to_i)
      end

      # Non-numeric slug: /shats or /shats/index
      # Extract first non-numeric path segment and look up in HtmlDir.
      # HtmlDir.person_id stores Authority IDs (see HtmlFileController#render_by_legacy_url).
      segment = path.split('/').compact_blank.first
      return nil if segment.blank?
      return nil if segment.match?(/\A\d+\z/)

      html_dir = HtmlDir.find_by(path: segment)
      return nil if html_dir.nil? || html_dir.person_id.nil?

      Authority.find_by(id: html_dir.person_id)
    end

    def find_by_wikidata(html_doc)
      qid = extract_wikidata_qid(html_doc)
      return nil if qid.blank?

      byp_id = fetch_byp_id_from_wikidata(qid)
      return nil if byp_id.blank?

      Authority.find_by(id: byp_id.to_i)
    end

    def extract_wikidata_qid(html_doc)
      html_doc.css('a[href]').each do |link|
        href = link['href'].to_s
        if (match = href.match(WIKIDATA_ENTITY_PATTERN))
          return match[1]
        end
      end

      nil
    end

    def fetch_byp_id_from_wikidata(qid)
      response = Faraday.get("#{WIKIDATA_API_BASE}/w/rest.php/wikibase/v1/entities/items/#{qid}")
      return nil unless response.success?

      data = JSON.parse(response.body)
      claims = data.dig('statements', WIKIDATA_PBY_PROPERTY)
      return nil if claims.blank?

      claims.first.dig('value', 'content')
    rescue JSON::ParserError, Faraday::Error => e
      Rails.logger.warn("Lexicon::AssociateAuthority: failed to fetch Wikidata for #{qid}: #{e.message}")
      nil
    end

    def find_by_name(lex_person)
      entry = lex_person.entry
      return nil unless entry

      name = entry.title
      return nil if name.blank?

      authorities = Authority.where(name: name)
      authorities.one? ? authorities.first : nil
    end
  end
end
