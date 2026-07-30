# frozen_string_literal: true

require 'rails_helper'

# Regression coverage for the tag-proposal popup on narrow (mobile) viewports:
# the mode toggle (propose a tag / pick from the full list) used to overflow the
# popup, and the suggestion-heuristic tabs used to render as a plain list rather
# than a usable tab strip.
RSpec.describe 'Tag proposal popup on mobile', :js, type: :system do
  let(:user) { create(:user) }
  let!(:base_user) { BaseUser.create!(user: user) }
  let(:author) { create(:authority, toc: create(:toc)) }
  let(:manifestation) { create(:manifestation, author: author) }
  let(:other_work) { create(:manifestation, author: author) }
  let!(:tag_by_author) { create(:tag, status: :approved, name: 'שירה עברית') }
  let!(:popular_tag) { create(:tag, status: :approved, name: 'ספרות ילדים ונוער') }
  let!(:unrelated_tag) { create(:tag, status: :approved, name: 'פילוסופיה של הלשון') }

  let(:viewport_width) { 390 }
  let(:viewport_height) { 844 }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    # populate all four suggestion heuristics: tags used on the author's other
    # works, the user's frequent tags, the user's recent tags, and popular tags
    create(:tagging, taggable: other_work, tag: tag_by_author, status: :approved, suggester: user)
    create(:tagging, taggable: other_work, tag: popular_tag, status: :approved, suggester: user)
    create(:tagging, taggable: create(:manifestation), tag: unrelated_tag, status: :approved, suggester: user)

    base_user.set_preference(:accepted_tag_policy, 'true')
    # same logged-in-user stubbing the project's own spec/support/test_helpers.rb uses
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:base_user).and_return(base_user)
    # rubocop:enable RSpec/AnyInstance

    resize_window(viewport_width, viewport_height)
    visit manifestation_path(manifestation)
  end

  after do
    resize_window(1400, 1400)
  end

  def resize_window(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def open_tag_popup
    find('#initiate-add-tag').click
    expect(page).to have_css('#add_tagging_tabs > ul > li', count: 2, wait: 5)
  end

  # geometry and computed styles of the elements matching +selector+
  def boxes(selector)
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#{selector}')).map(function (el) {
        var r = el.getBoundingClientRect();
        var s = getComputedStyle(el);
        return { left: r.left, right: r.right, top: r.top, bottom: r.bottom,
                 width: r.width, height: r.height,
                 marker: s.listStyleType, display: s.display };
      })
    JS
  end

  # how much wider the scrollable content of +selector+ is than its visible box
  def horizontal_overflow(selector)
    page.evaluate_script(
      "(function (el) { return el.scrollWidth - el.clientWidth; })(document.querySelector('#{selector}'))"
    )
  end

  # width the text of +selector+ needs, compared to the width it actually gets.
  # An element clipped with text-overflow: ellipsis still reports its full text
  # in the DOM, so the text has to be measured off-screen to detect truncation.
  def text_width_vs_available(selector)
    page.evaluate_script(<<~JS)
      (function (el) {
        var style = getComputedStyle(el);
        var probe = document.createElement('span');
        probe.textContent = el.textContent;
        probe.style.font = style.font;
        probe.style.fontSize = style.fontSize;
        probe.style.fontFamily = style.fontFamily;
        probe.style.fontWeight = style.fontWeight;
        probe.style.whiteSpace = 'nowrap';
        probe.style.position = 'absolute';
        probe.style.visibility = 'hidden';
        document.body.appendChild(probe);
        var needed = probe.getBoundingClientRect().width;
        probe.remove();
        return [needed, el.clientWidth];
      })(document.querySelector('#{selector}'))
    JS
  end

  shared_examples 'a usable popup layout' do
    before { open_tag_popup }

    it 'shows the popup title in full rather than truncating it' do
      expect(find('#generalDlg .popup-top .headline-2-v02')).to have_text(I18n.t(:add_tag), exact: true)

      needed, available = text_width_vs_available('#generalDlg .popup-top .headline-2-v02')
      expect(needed).to be <= available + 1
    end

    it 'lays out the mode toggle as a two-up segmented control inside the viewport' do
      tabs = boxes('#add_tagging_tabs > ul > li')
      expect(tabs.size).to eq 2

      tabs.each do |tab|
        expect(tab['left']).to be >= 0
        expect(tab['right']).to be <= viewport_width
        expect(tab['width']).to be > 0
      end

      # both halves sit on the same row and share the width evenly
      expect(tabs[0]['top']).to be_within(2).of(tabs[1]['top'])
      expect(tabs[0]['width']).to be_within(2).of(tabs[1]['width'])
      expect(horizontal_overflow('#add_tagging_tabs > ul')).to be <= 1
    end

    it 'renders the suggestion heuristics as chips, not as a bulleted list' do
      expect(page).to have_css('#suggestion_heuristics > ul > li', minimum: 3, wait: 5)

      boxes('#suggestion_heuristics > ul > li').each do |chip|
        expect(chip['marker']).to eq 'none'
        expect(chip['left']).to be >= 0
        expect(chip['right']).to be <= viewport_width
      end
    end

    it 'keeps every heuristic chip reachable without horizontal scrolling' do
      expect(page).to have_css('#suggestion_heuristics > ul > li', minimum: 3, wait: 5)
      expect(horizontal_overflow('#suggestion_heuristics > ul')).to be <= 1
    end

    it 'does not make the page scroll sideways' do
      expect(horizontal_overflow('html')).to be <= 1
    end
  end

  context 'when on a small phone (320px)' do
    let(:viewport_width) { 320 }
    let(:viewport_height) { 640 }

    it_behaves_like 'a usable popup layout'
  end

  context 'when on a common Android phone (360px)' do
    let(:viewport_width) { 360 }
    let(:viewport_height) { 740 }

    it_behaves_like 'a usable popup layout'
  end

  context 'when on a large phone (390px)' do
    it_behaves_like 'a usable popup layout'
  end

  describe 'suggesting a tag' do
    before { open_tag_popup }

    it 'switches between suggestion heuristics' do
      expect(page).to have_css('#used_on_other_works', visible: :visible, wait: 5)
      expect(page).to have_css('#popular_tags', visible: :hidden)

      find('#suggestion_heuristics > ul a', text: I18n.t(:popular_tags)).click

      expect(page).to have_css('#popular_tags', visible: :visible)
      expect(page).to have_css('#used_on_other_works', visible: :hidden)
    end

    it 'fills the tag field when a suggested tag is tapped' do
      within('#used_on_other_works') do
        click_button 'שירה עברית'
      end

      expect(find('#tag').value).to eq 'שירה עברית'
      expect(find('#tag_id', visible: :all).value).to eq tag_by_author.id.to_s
      expect(page).to have_css('#submit_tagging:not(.disabled)')
    end

    it 'proposes a suggested tag and shows it as pending on the page' do
      within('#used_on_other_works') do
        click_button 'שירה עברית'
      end
      find('#submit_tagging').click

      expect(page).to have_css('#generalDlg', visible: :hidden, wait: 5)
      within('.tags-area') do
        expect(page).to have_link('שירה עברית')
      end
      expect(Tagging.where(tag: tag_by_author, taggable: manifestation).pending.count).to eq 1
    end

    it 'proposes a brand new tag typed by hand' do
      fill_in 'tag', with: 'תגית חדשה לגמרי'
      expect(page).to have_css('#submit_tagging:not(.disabled)')
      find('#submit_tagging').click

      expect(page).to have_css('#generalDlg', visible: :hidden, wait: 5)
      within('.tags-area') do
        expect(page).to have_content('תגית חדשה לגמרי')
      end
      expect(Tag.find_by(name: 'תגית חדשה לגמרי')).to be_present
    end

    it 'closes the popup with the mobile back button' do
      find('#generalDlg .popup-top button[data-dismiss="modal"]').click
      expect(page).to have_css('#generalDlg', visible: :hidden, wait: 5)
    end
  end

  describe 'picking from the full tag list' do
    before do
      open_tag_popup
      find('#add_tagging_tabs > ul a', text: I18n.t(:select_from_full_list)).click
    end

    it 'shows the full list panel and hides the suggestion panel' do
      expect(page).to have_css('#tag_list', visible: :visible)
      expect(page).to have_css('#add-tag-form', visible: :hidden)
      expect(page).to have_css('#tag_list .full-tags-list .list-group-item', minimum: 3, wait: 5)
    end

    it 'keeps the full list inside the viewport' do
      expect(page).to have_css('#tag_list .full-tags-list .list-group-item', minimum: 3, wait: 5)

      boxes('#tag_list .full-tags-list .list-group-item').each do |item|
        expect(item['left']).to be >= 0
        expect(item['right']).to be <= viewport_width
      end
    end

    it 'proposes a tag selected from the full list' do
      expect(page).to have_css('#tag_list .full-tags-list .list-group-item', minimum: 3, wait: 5)
      within('#tag_list .full-tags-list') do
        find('.list-group-item', text: 'פילוסופיה של הלשון').click
      end
      expect(find('#tag', visible: :all).value).to eq 'פילוסופיה של הלשון'

      find('#add_tagging_tabs > ul a', text: I18n.t(:i_want_to_suggest_a_tag)).click
      find('#submit_tagging').click

      expect(page).to have_css('#generalDlg', visible: :hidden, wait: 5)
      expect(Tagging.where(tag: unrelated_tag, taggable: manifestation).pending.count).to eq 1
    end
  end

  describe 'desktop layout is unaffected' do
    let(:viewport_width) { 1400 }
    let(:viewport_height) { 1000 }

    before { open_tag_popup }

    it 'still shows the mode tabs side by side, hugging their labels' do
      tabs = boxes('#add_tagging_tabs > ul > li')
      expect(tabs.size).to eq 2
      expect(tabs[0]['top']).to be_within(2).of(tabs[1]['top'])
      # unlike mobile, desktop tabs are as wide as their labels, not half the popup
      expect(tabs[0]['width']).not_to be_within(2).of(tabs[1]['width'])
    end

    it 'still renders the heuristics as a tab strip without bullets' do
      expect(page).to have_css('#suggestion_heuristics > ul > li', minimum: 3, wait: 5)

      boxes('#suggestion_heuristics > ul > li').each do |chip|
        expect(chip['marker']).to eq 'none'
      end
    end
  end
end
