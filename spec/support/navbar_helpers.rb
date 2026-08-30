# frozen_string_literal: true

# Helpers for specs asserting on the author page's in-page navbar.
#
# The navbar is rendered ahead of the TOC body in the same response, and the two repeat the same
# role headings and count badges -- so a spec that means to assert on the navbar has to isolate it
# first, or it will happily match the TOC instead and pass for the wrong reason.
module NavbarHelpers
  NAVBAR_START = 'book-nav-full'
  NAVBAR_END = 'mobile-navbar-backdrop'

  # The in-page navbar markup, without the TOC body that follows it. Fails with a legible message
  # rather than a nil-range error if the response turns out not to contain a navbar at all.
  def navbar_fragment(body)
    expect(body).to include(NAVBAR_START), "response contains no in-page navbar (no '#{NAVBAR_START}')"
    expect(body).to include(NAVBAR_END), "in-page navbar is not terminated (no '#{NAVBAR_END}')"

    body[body.index(NAVBAR_START)...body.index(NAVBAR_END)]
  end
end

RSpec.configure do |config|
  config.include NavbarHelpers, type: :request
end
