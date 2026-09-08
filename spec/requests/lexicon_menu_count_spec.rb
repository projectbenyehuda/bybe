# frozen_string_literal: true

require 'rails_helper'

# The Authors menu used to advertise only the migrated (published) lexicon entries, which
# undercounts the lexicon: unmigrated entries are served just as well, by redirecting to their
# legacy PHP file. The menu now reports every publicly reachable entry.
RSpec.describe 'Lexicon count in the Authors menu', type: :request do
  around do |example|
    I18n.with_locale(:he) { example.run }
  end

  before { clean_tables }

  def authors_menu_text
    menu = Nokogiri::HTML(response.body).at_css('#menu-authors')
    expect(menu).not_to be_nil, 'the Authors dropdown (#menu-authors) is missing from the page'
    menu.text
  end

  it 'counts unmigrated entries as well as published ones' do
    create(:lex_entry, status: :published)
    create(:lex_file, :person, entry_status: :raw)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(LexEntry.cached_public_count).to eq 2
    expect(authors_menu_text).to include(
      I18n.t(:x_authors_in_the_project_and_y_in_the_lexicon, x: Authority.cached_count, y: 2)
    )
    expect(authors_menu_text).to include("2 #{I18n.t(:authors)}")
  end
end
