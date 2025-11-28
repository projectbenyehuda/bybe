# frozen_string_literal: true

# Service to convert new publications hash to HTML string
class TextifyNewPubs < ApplicationService
  def call(pubs)
    ret = ''
    pubs.each do |genre|
      next unless genre[1].is_a?(Array) # skip the :latest key

      worksbuf = "<strong>#{textify_genre(genre[0])}:</strong> "
      first = true
      genre[1].each do |m|
        title = m.expression.title
        if m.expression.translation
          per = m.expression.work.authors[0] # TODO: add handing for several persons
          unless per.nil?
            title += " #{I18n.t(:by)} #{per.name}"
          end
        end
        if first
          first = false
        else
          worksbuf += '; '
        end
        worksbuf += "<a href=\"/read/#{m.id}\">#{title}</a>"
      end
      ret += worksbuf + '<br />'
    end
    ret
  end

  private

  def textify_genre(genre)
    return I18n.t(:unknown) if genre.blank?

    I18n.t("genre_values.#{genre}")
  end
end
