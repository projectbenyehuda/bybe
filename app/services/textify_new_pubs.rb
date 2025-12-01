# frozen_string_literal: true

# Service to convert array of manifestations to HTML string grouped by genre
class TextifyNewPubs < ApplicationService
  def call(manifestations)
    return '' if manifestations.blank?

    # Group manifestations by genre
    grouped = manifestations.group_by { |m| m.expression.work.genre }

    ret = ''
    grouped.each do |genre, works|
      worksbuf = "<strong>#{textify_genre(genre)}:</strong> "
      first = true
      works.each do |m|
        title = m.expression.title
        if m.expression.translation
          per = m.expression.work.authors[0] # TODO: add handling for several persons
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
