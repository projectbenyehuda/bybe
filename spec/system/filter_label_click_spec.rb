# frozen_string_literal: true

require 'rails_helper'

# The filter option labels used to have no `for` attribute, so the only way to
# apply a filter was to hit the 18x18px checkbox itself -- the label text, which
# is most of the option's visible area, was dead to clicks.
describe 'Filter option labels are clickable', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      create(:manifestation, author: create(:authority, gender: 'female'))
      create(:manifestation, author: create(:authority, gender: 'male'))
    end
  end

  after do
    Chewy.massacre
  end

  it 'applies the filter when its label text is clicked' do
    visit authors_path

    find('label[for="gender_female"]', visible: :visible).click

    expect(page).to have_css('.tag', text: 'יוצר: נקבה', wait: 5)
    expect(page).to have_field('gender_female', type: 'checkbox', checked: true, visible: :visible)
  end

  it 'clears the filter when the label text is clicked again' do
    visit authors_path

    find('label[for="gender_female"]', visible: :visible).click
    expect(page).to have_css('.tag', text: 'יוצר: נקבה', wait: 5)

    find('label[for="gender_female"]', visible: :visible).click

    expect(page).not_to have_css('.tag', text: 'יוצר: נקבה', wait: 5)
    expect(page).to have_field('gender_female', type: 'checkbox', checked: false, visible: :visible)
  end
end
