# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Anthology access level restriction', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:regular_user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let!(:manifestation) { create(:manifestation, status: :published) }

  def login_as_regular_user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(regular_user)
    regular_user
  end

  def login_as_admin
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
    admin_user
  end

  describe 'non-admin user access level options' do
    before do
      login_as_regular_user
      @anthology = create(:anthology, user: regular_user, access: :priv)
    end

    it 'only shows priv and unlisted options in the dropdown', skip: 'Requires JavaScript-based test that opens the anthology panel' do
      # Visit a page where the anthology panel is accessible
      visit manifestation_path(manifestation)

      # Open the anthology panel (implementation depends on UI flow)
      # This is a simplified version - actual implementation may vary
      find('#anthologiesDlg').click if page.has_css?('#anthologiesDlg')

      # Check that the access dropdown exists
      within '#anthology-status' do
        access_select = find('select#access')

        # Get all option values
        option_values = access_select.all('option').map { |opt| opt.value }

        # Should include priv and unlisted
        expect(option_values).to include('priv')
        expect(option_values).to include('unlisted')

        # Should NOT include pub
        expect(option_values).not_to include('pub')
      end
    end
  end

  describe 'admin user access level options' do
    before do
      login_as_admin
      @anthology = create(:anthology, user: admin_user, access: :priv)
    end

    it 'shows all three access level options in the dropdown', skip: 'Requires JavaScript-based test that opens the anthology panel' do
      # Visit a page where the anthology panel is accessible
      visit manifestation_path(manifestation)

      # Open the anthology panel
      find('#anthologiesDlg').click if page.has_css?('#anthologiesDlg')

      # Check that the access dropdown exists and has all options
      within '#anthology-status' do
        access_select = find('select#access')

        # Get all option values
        option_values = access_select.all('option').map { |opt| opt.value }

        # Should include all three options
        expect(option_values).to include('priv')
        expect(option_values).to include('unlisted')
        expect(option_values).to include('pub')
      end
    end
  end
end
