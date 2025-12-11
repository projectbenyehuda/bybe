# frozen_string_literal: true

module TestHelpers
  # Creates an editor user with edit_catalog privileges for testing
  # Returns the created user, or the existing one if already created in this test run
  def create_catalog_editor
    @catalog_editor ||= begin
      user = create(:user, editor: true)
      # Grant edit_catalog editor bits
      ListItem.create!(listkey: 'edit_catalog', item: user)
      user
    end
  end

  # Login helper for system specs using rack_test driver
  def login_as_catalog_editor
    user = create_catalog_editor
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_editor).and_return(true)
    user
  end
end

RSpec.configure do |config|
  config.include TestHelpers, type: :system
  config.include TestHelpers, type: :request
  config.include TestHelpers, type: :controller
end
