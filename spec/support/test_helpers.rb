# frozen_string_literal: true

module TestHelpers
  # Logs the given user in for the duration of the example. This is the single place the suite
  # stubs authentication -- reach for it instead of hand-rolling the stub in individual specs.
  # rubocop:disable RSpec/AnyInstance -- the app has no password login to drive; OmniAuth only
  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    user
  end
  # rubocop:enable RSpec/AnyInstance

  # The last response's body as a Capybara node, so that a request spec can assert on selectors
  # (`expect(rendered).to have_css(...)`) instead of grepping the raw HTML string. Asserting on a
  # selector proves the markup was rendered where it belongs; a bare `body.include?('text')` also
  # passes when the text happens to appear somewhere else entirely.
  # Note this is Capybara::Node::Simple, not a session: it is a snapshot with no waiting behaviour,
  # which is exactly right for a request spec (there is no JavaScript and nothing to wait for).
  def rendered
    Capybara.string(response.body)
  end

  BROWSER_USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120'

  # Ahoy.track_bots is false and the default controller-spec user agent ('Rails Testing') is
  # classified as a bot, so tracking silently records nothing. Call this before the request in any
  # spec that asserts on Ahoy::Event rows.
  def stub_browser_user_agent
    request.user_agent = BROWSER_USER_AGENT
  end

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
    login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:require_editor).and_return(true)
    user
  end

  # Creates an editor user with batch_editing privileges for testing
  def create_batch_editor
    @batch_editor ||= begin
      user = create(:user, editor: true)
      ListItem.create!(listkey: 'batch_editing', item: user)
      user
    end
  end

  # Login helper for mass-update / saved-selections specs
  def login_as_batch_editor
    user = create_batch_editor
    login_as(user)
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
    login_as(user)
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

  # Creates an editor user with edit_lexicon privileges for testing
  # Returns the created user, or the existing one if already created in this test run
  def create_lexicon_editor
    @lexicon_editor ||= begin
      user = create(:user, editor: true)
      # Grant edit_lexicon editor bits
      ListItem.create!(listkey: 'edit_lexicon', item: user)
      user
    end
  end

  # Login helper for lexicon specs
  def login_as_lexicon_editor
    user = create_lexicon_editor
    login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:require_editor).and_return(true)
    user
  end
end

RSpec.configure do |config|
  config.include TestHelpers, type: :system
  config.include TestHelpers, type: :request
  config.include TestHelpers, type: :controller
end
