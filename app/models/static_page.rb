# frozen_string_literal: true

# This class represents a static page in the application, which can be created and edited by administrators.
class StaticPage < ApplicationRecord
  include DownloadLink

  # attr_accessible :tag, :title, :body, :status, :mode, :ltr

  has_paper_trail
  enum :status, { unpublished: 0, published: 1 }
  enum :mode, { plain_markdown: 0, cards: 1, cards_with_shortcuts: 2 }
  has_many_attached :images, dependent: :destroy
  
  def english?
    buf = self.body[0..(self.body.length > 1000 ? 1000 : -1)]
    hebcount = 0
    buf.each_codepoint{|cp| hebcount += 1 if buf.is_hebrew_codepoint_utf8(cp)}
    if hebcount > buf.length / 2
      return false
    else
      return true
    end
  end

  def prepare_markdown
    markdown = MultiMarkdown.new(self.body).to_html.force_encoding('UTF-8')
    unless self.mode == 'plain_markdown' # then all paragraphs should be in cards
      sections = markdown.split(/(<h2.*?<\/h2>)/)
      newbuf = '<span class="headline-1-v02">' + self.title + '</span>'
      extrastyle = self.ltr ? 'style="direction:ltr;text-align:left"' : ''
      i = 0
      sections.each do |s|
        if s[0..2] == '<h2'
          s.match(/<h2.*?>(.*?)<\/h2>/)
          title = $1 or ''
          newbuf += "<div class=\"by-card-v02\"><div class=\"by-card-header-v02\"><span class=\"headline-2-v02\" #{extrastyle}>#{title}</span></div><div class=\"by-card-content-v02\">"
        else
          newbuf += s + '</div></div>' unless i == 0 # close card
        end
        i += 1
      end
      markdown = newbuf
    end
    return markdown
  end
end
