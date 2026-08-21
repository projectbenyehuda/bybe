# frozen_string_literal: true

require 'rails_helper'

# Regression test for a bug where tapping the "intellectual property" label (and other
# focus-triggered popovers) did nothing on iPhone, while working fine on desktop and Android.
#
# Root cause: these links use Bootstrap's `trigger: 'focus'` popover option, but iOS Safari
# never fires a `focus` event when a plain <a> (without `tabindex`) is tapped, so the popover
# never opens. Adding `tabindex="0"` makes iOS Safari treat the link as focusable on tap.
describe 'Focus-triggered popover links are focusable on tap (iOS Safari fix)' do
  it 'has tabindex on the intellectual property popover link on Manifestation#read' do
    manifestation = create(:manifestation, status: :published)

    visit manifestation_path(manifestation)

    expect(page).to have_css('a.help[data-trigger="focus"][tabindex="0"]', visible: :all)
  end

  it 'has tabindex on all focus-triggered popover links on the author TOC page' do
    author = create(:authority, name: 'Test Author', gender: 'male')

    visit authority_path(author)

    focus_popovers = page.all(:css, 'a.help[data-trigger="focus"]', visible: :all)

    # intellectual property (rendered twice: header card and body), period, sort-and-filter
    expect(focus_popovers.size).to eq(4)
    focus_popovers.each do |link|
      expect(link[:tabindex]).to eq('0')
    end
  end
end
