# frozen_string_literal: true

require 'rails_helper'

# A collection the authority edited is listed on their page by title only: its texts (other
# people's works) appear neither in the grouped view nor in the flat list built from it.
RSpec.describe 'Author TOC edited collections', :js, type: :system do
  # Lazy `let` so the WebDriver skip in the before hook short-circuits without DB setup.
  let(:editor) { create(:authority, name: 'Editing Author') }
  let(:anthology) { create(:collection, title: 'Edited Anthology', collection_type: :volume, editors: [editor]) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    create(:manifestation, title: 'Somebody Elses Story', status: :published, author: create(:authority),
                           editor: editor, collections: [anthology])
    create(:manifestation, title: 'An Own Story', status: :published, author: editor,
                           collections: [create(:collection, title: 'Own Volume', authors: [editor])])
  end

  it 'shows the edited collection title as a link, without its texts' do
    visit authority_path(editor)

    within("#cwrapper_#{anthology.id}") do
      expect(page).to have_link('Edited Anthology', href: collection_path(anthology))
      expect(page).to have_no_css('.manifestation-node')
    end
    expect(page).to have_no_content('Somebody Elses Story')
  end

  it 'leaves the texts of the edited collection out of the flat list' do
    visit authority_path(editor)
    find("#sort_by option[value='title']").select_option

    expect(page).to have_css('#sorted_card .manifestation-node', text: 'An Own Story')
    expect(page).to have_no_css('#sorted_card .manifestation-node', text: 'Somebody Elses Story')
  end
end
