# frozen_string_literal: true

# Shared factory for the value Lexicon::CheckExternalLinks#check_url returns, so the specs that
# stub the checker (request, system and service specs) don't each spell out the Result constructor.
module LinkCheckHelpers
  # +unverifiable+ marks a host that answered with a bot challenge: the status says nothing about
  # whether the link works, and an editor has to check it in a browser.
  def link_check_result(status, unverifiable: false)
    Lexicon::CheckExternalLinks::Result.checked(status, unverifiable: unverifiable)
  end
end

RSpec.configure do |config|
  config.include LinkCheckHelpers
end
