# frozen_string_literal: true

require 'rails_helper'

# The desktop dropdown (#menu-authors) links the Lexicon item to the public
# entries list (lexicon_root_path => entries#list). The mobile sidenav
# (#menuMobile) pointed at lexicon_entries_path (/lex/entries), which is the
# editor-only backend index: anonymous visitors were bounced to '/' with a
# "not an editor" error, and editors landed in the lexicon backend instead of
# the public list.
RSpec.describe 'Mobile menu Lexicon link', type: :request do
  around do |example|
    I18n.with_locale(:he) { example.run }
  end

  def mobile_menu
    menu = Nokogiri::HTML(response.body).at_css('#menuMobile')
    expect(menu).not_to be_nil, 'the mobile menu (#menuMobile) is missing from the page'
    menu
  end

  before { get root_path }

  it 'links to the public lexicon entries list, not the editor-only backend' do
    expect(response).to have_http_status(:ok)

    links = mobile_menu.css('a').select { |a| a.text.include?(I18n.t(:lexicon_name)) }
    expect(links).not_to be_empty, 'no link to the lexicon in the mobile menu'
    hrefs = links.pluck('href')
    expect(hrefs).to include(lexicon_root_path)
    expect(hrefs).not_to include(lexicon_entries_path)
  end

  it 'lets an anonymous visitor reach the linked page' do
    link = mobile_menu.css('a').find { |a| a.text.include?(I18n.t(:lexicon_name)) }
    expect(link).not_to be_nil, 'no link to the lexicon in the mobile menu'
    href = link['href']

    get href
    expect(response).to have_http_status(:ok)
  end
end
