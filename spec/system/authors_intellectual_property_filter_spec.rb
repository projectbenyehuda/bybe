# frozen_string_literal: true

require 'rails_helper'

# 'copyrighted' is deliberately not offered as a filter on /authors. The view
# used to drop it from the labels and icons only, leaving an unlabeled checkbox
# in the list.
describe 'Authors intellectual property filter' do
  before do
    Chewy.strategy(:atomic) do
      create(:manifestation, author: create(:authority, intellectual_property: :public_domain))
      create(:manifestation, author: create(:authority, intellectual_property: :copyrighted))
    end
  end

  after do
    Chewy.massacre
  end

  it 'offers no checkbox for the copyrighted status' do
    visit authors_path

    expect(page).to have_css('#intellectual_property_public_domain', visible: :all)
    expect(page).not_to have_css('#intellectual_property_copyrighted', visible: :all)
  end

  it 'labels every checkbox it does offer' do
    visit authors_path

    labels = page.all('#collfcollfintellectual_property .filter-checkbox label', visible: :all)
    expect(labels).not_to be_empty
    # Each label carries the status name plus a "(count)" span; a value missing
    # from the labels hash would leave only the count.
    labels.each do |label|
      expect(label.text(:all).sub(/\(.*\)\s*\z/, '').strip).not_to be_empty
    end
  end
end
