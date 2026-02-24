# frozen_string_literal: true

require 'rails_helper'

# Regression tests for UX improvements introduced in the lex_ux_review branch.
describe 'Lexicon entries UX improvements' do
  describe 'Entry show page (#show)' do
    let(:entry) { create(:lex_entry, :person, status: :published) }

    before { get "/lex/entries/#{entry.id}" }

    it 'renders back-to-list link in the header breadcrumb area' do
      expect(response.body).to include(I18n.t('lexicon.entries.list.entries_list_breadcrumb'))
      expect(response.body).to include(I18n.t(:back_to_list))
    end

    it 'does not render a bare pipe-separated edit link outside the main content' do
      # The old pattern was: link_to(t(:edit), ...) \| link_to(t(:back), ...)
      # which produced unstyled text with a literal | character between the links.
      # After the fix, navigation is in the header partial and uses proper CSS classes.
      expect(response.body).not_to match(%r{</a>\s*\|\s*<a})
    end

    it 'includes the navbar section with correct aria-selected on the active biography link' do
      # Biography is the first section and should be aria-selected=true on page load
      expect(response.body).to include('aria-selected="true"')
      # The first nav-link (biography) should carry the active class and aria-selected=true
      expect(response.body).to match(/nav-link active.*aria-selected="true"|aria-selected="true".*nav-link active/m)
    end

    it 'does not have the old reversed aria-selected pattern (active link with aria-selected=false)' do
      # This was the bug: .active class with aria-selected="false" on the same element
      expect(response.body).not_to match(/class="nav-link active"[^>]*aria-selected="false"/)
      expect(response.body).not_to match(/aria-selected="false"[^>]*class="nav-link active"/)
    end
  end

  describe 'Entry show page for publications (#show)' do
    let(:entry) { create(:lex_entry, :publication, status: :published) }

    before { get "/lex/entries/#{entry.id}" }

    it 'renders publication navbar items with the nav-link class for consistent hover/active styling' do
      # Publication nav items previously lacked .nav-link, so the peach2-lexicon hover/active
      # CSS rules never applied to them. Verify that nav-link appears inside #genre-nav.
      expect(response.body).to match(/<ul[^>]+id="genre-nav".*?<a[^>]+class="[^"]*nav-link/m)
    end
  end

  describe 'Entry list page (#list)' do
    before { post '/lex/list' }

    it 'renders the mobile filter toggle button with correct accessibility attributes' do
      expect(response.body).to include('lex-mobile-filter-toggle')
      expect(response.body).to include('type="button"')
      expect(response.body).to include('aria-controls="lex-filter-card"')
      expect(response.body).to include('aria-expanded="false"')
      expect(response.body).to include(I18n.t('lexicon.entries.list.filters.show_filters'))
    end

    it 'renders the filter card with a role and aria-label for accessibility' do
      expect(response.body).to include('lex-filter-card')
      expect(response.body).to include('role="region"')
      expect(response.body).to include(I18n.t('lexicon.entries.list.filters.filter_panel'))
    end
  end

  describe 'Entry list page with active filters' do
    let!(:male_entry) do
      entry = create(:lex_entry, :person, status: :published)
      entry.lex_item.update!(gender: :male)
      entry
    end

    before { post '/lex/list', params: { ckb_genders: ['male'] } }

    it 'renders filter pills with × as the remove symbol (not a bare hyphen)' do
      # Active filters render as pill buttons with a .tag-x span.
      # Verify the × symbol is present and the old "-" (hyphen) pattern is absent.
      expect(response.body).to include('tag-x')
      expect(response.body).to include('×')
      expect(response.body).not_to match(%r{<span[^>]+class="pointer tag-x[^"]*"[^>]*>-</span>})
      expect(response.body).not_to match(%r{<span[^>]+class="pointer tag-x[^"]*"[^>]*>&ndash;</span>})
    end
  end
end
