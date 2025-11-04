# frozen_string_literal: true

# Generates alternate Hebrew forms of a given string (strips nikkud, adds matres lectionis)
class AlternateHebrewForms < ApplicationService
  # @param str string to generate alternate forms for
  def call(str)
    return [] if str.blank?

    s = str.strip
    forms = []
    stripped = s.strip_nikkud
    forms << stripped unless stripped == s
    s_with_matres = s.naive_full_nikkud
    forms << s_with_matres.strip_nikkud unless s_with_matres == s
    forms.uniq
  end
end
