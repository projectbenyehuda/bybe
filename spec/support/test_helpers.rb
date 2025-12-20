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

  # Creates an editor user with moderate_tags privileges for testing
  def create_moderator
    @moderator ||= begin
      user = create(:user, editor: true)
      # Grant moderate_tags editor bits
      ListItem.create!(listkey: 'moderate_tags', item: user)
      ListItem.create!(listkey: 'editors', item: user)
      user
    end
  end

  # Login helper for tag moderation specs
  def login_as_moderator
    user = create_moderator
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:require_editor).and_return(true)
    # Store user for mock_tagging_lock to use
    @current_test_user = user
    user
  end

  # Mock the tagging lock for system specs
  def mock_tagging_lock
    # Create actual lock file with current user's ID
    # This allows the real obtain_tagging_lock method to work properly
    user = @current_test_user || create(:user, editor: true)
    File.write('/tmp/tagging.lock', "#{user.id}")
  end

  # Clean up tagging lock file after spec
  def cleanup_tagging_lock
    File.delete('/tmp/tagging.lock') if File.exist?('/tmp/tagging.lock')
  end
end

RSpec.configure do |config|
  config.include TestHelpers, type: :system
  config.include TestHelpers, type: :request
  config.include TestHelpers, type: :controller
end
