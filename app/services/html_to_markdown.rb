# frozen_string_literal: true

# service to convert HTML snippet to MultiMarkdown
class HtmlToMarkdown < ApplicationService
  def call(html)
    return '' if html.blank?

    PandocRuby.convert(
      html,
      M: 'dir=rtl',
      from: :html,
      to: :markdown_mmd
    ).force_encoding('UTF-8')
  end
end
