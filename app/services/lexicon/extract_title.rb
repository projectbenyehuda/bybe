# frozen_string_literal: true

module Lexicon
  # Service to extract title from Lexicon entry
  class ExtractTitle < ApplicationService
    def call(fname)
      buf = File.read(fname).gsub("\r\n", "\n")
      buf = buf[0..3000] if buf.length > 3000 # the entry name seems to always occur a little after 2000 chars

      title = buf.gsub("\n", ' ').scan(%r{<p align="center"><font size="[4|5]".*?>(.*?)</}).join(' ')
      if title.blank?
        buf =~ %r{<title>(.*?)</title>}m
        title = Regexp.last_match(1) if Regexp.last_match(1)
      end
      title.strip.gsub('&nbsp;', '').gsub('בהכנה', '')
    end
  end
end
