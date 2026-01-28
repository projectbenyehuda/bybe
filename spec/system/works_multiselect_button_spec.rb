# frozen_string_literal: true

require 'rails_helper'

describe 'Works browse multiselect button' do
  after do
    Chewy.massacre
  end

  before do
    Chewy.strategy(:atomic) do
      create_list(:manifestation, 3, status: :published)
    end
  end

  describe 'multi-select button visibility' do
    context 'when user is not logged in' do
      it 'does not display the multi-select button' do
        visit '/works'

        expect(page).not_to have_css('#multiselect_btn')
        expect(page).not_to have_css('#select-all')
      end

      it 'still displays the sort-by dropdown' do
        visit '/works'

        expect(page).to have_css('#sort_by_dd')
        expect(page).to have_text(/מיון לפי/)
      end
    end

    context 'when user is logged in' do
      let(:user) { create(:user) }

      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      end

      it 'displays the multi-select button' do
        visit '/works'

        expect(page).to have_css('#multiselect_btn')
      end

      it 'displays the select-all checkbox when multi-select is activated', :js do
        visit '/works'

        # Initially hidden
        expect(page).to have_css('#select-all', visible: :hidden)

        # Click multi-select button
        find('#multiselect_btn').click

        # Now visible
        expect(page).to have_css('#select-all', visible: :visible)
      end

      it 'still displays the sort-by dropdown' do
        visit '/works'

        expect(page).to have_css('#sort_by_dd')
        expect(page).to have_text(/מיון לפי/)
      end
    end
  end
end
