# frozen_string_literal: true

require 'rails_helper'

# Regression for beads_by-hjt: the author-page side navbar rendered the literal
# "%{gender_suffix}" because shared/_newtoc_navbar called
# t(:works_about_this_author) without the interpolation param the string requires.
RSpec.describe 'Author navbar "works about this author" label', type: :request do
  let(:volume) { create(:collection, title: 'A Volume', collection_type: :volume) }
  # the literal placeholder that must never reach the page (not a format token here)
  let(:raw_placeholder) { '%{gender_suffix}' } # rubocop:disable Style/FormatStringToken

  def visit_author(author)
    work = create(:manifestation, author: author)
    create(:collection_item, collection: volume, item: work)
    create(:involved_authority, authority: author, item: volume, role: 'editor')
    get authority_path(author)
  end

  it 'never renders the raw interpolation placeholder' do
    visit_author(create(:authority, gender: 'male'))
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(raw_placeholder)
  end

  it 'interpolates the gender suffix for a female author' do
    visit_author(create(:authority, gender: 'female'))
    expect(response.body).not_to include(raw_placeholder)
    expect(response.body).to include(I18n.t(:works_about_this_author, gender_suffix: '/ת'))
  end
end
