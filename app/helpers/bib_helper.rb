# frozen_string_literal: true

module BibHelper
  @@bib_sources = {}
  def linkify_record(source, source_id)
    return link_to(source.title, url_for_record(source, source_id))
  end

  def textify_bib_source(id)
    BibSource.find_each { |x| @@bib_sources[x.id] = x.title } if @@bib_sources.empty?
    title = @@bib_sources[id]
    # If title looks like an i18n key (lowercase, underscores), try to translate it
    if title.present? && title == title.downcase && title.include?('_')
      I18n.t(title, default: title)
    else
      title
    end
  end
end
