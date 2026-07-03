# Testing Requirements

## CRITICAL: NO FEATURE OR BUG FIX IS COMPLETE WITHOUT PROPER TESTING

Before considering ANY work complete, you MUST:

1. **Run the existing test suite** to ensure no regressions:
   ```bash
   bundle exec rspec
   ```
   - Allow up to 15 minutes for the suite. It includes browser tests and Elasticsearch tests, which take longer.
   - All existing tests MUST pass
   - Fix any failing tests before submitting your work
   - If tests fail due to your changes, investigate and fix the root cause

2. **Write new tests** for your changes:
   - **For bug fixes**: Write a test that would have caught the bug (regression test)
   - **For new features**: Write tests covering the feature's functionality
   - **For UI changes**: Use Capybara system specs with JavaScript enabled (`js: true`)
   - **For API changes**: Write request specs testing the API endpoints
   - Exception: If the problem was in the tests themselves, fixing the tests is enough

3. **Verify your new tests pass**:
   ```bash
   bundle exec rspec path/to/your_new_spec.rb
   ```

4. **Run the full suite again** to ensure your new tests don't break anything:
   ```bash
   bundle exec rspec
   ```

**If you submit a PR without tests or with failing tests, it will be rejected.**

## Test Types and When to Use Them

- **Model specs** (`spec/models/`): Test model logic, validations, associations
- **Controller specs** (`spec/controllers/`): Test controller actions, params handling
- **Request specs** (`spec/requests/`): Test HTTP requests/responses, API endpoints
- **System specs** (`spec/system/`, requires `js: true`): Test full user interactions with JavaScript using Capybara
- **Service specs** (`spec/services/`): Test service objects and business logic

## CRITICAL: System Specs WebDriver Check

**ALL system specs with `js: true` MUST include a WebDriver availability check to prevent CI failures.**

The centralized check is already implemented in `spec/support/system_spec_helpers.rb`. You MUST add this check at the top of every system spec:

```ruby
# spec/system/your_feature_spec.rb
require 'rails_helper'

RSpec.describe 'Your feature', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  # ... rest of your tests
end
```

**This is MANDATORY** - without it, the CI will fail when WebDriver/Chrome is unavailable in the CI environment.

## Example: Testing a UI Bug Fix

When fixing a UI bug like scrollspy highlighting:
```ruby
# spec/system/manifestation_scrollspy_spec.rb
require 'rails_helper'

RSpec.describe 'Feature name', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  it 'properly highlights chapters on page load' do
    # Test the bug is fixed
  end

  it 'updates highlighting during scroll' do
    # Test dynamic behavior
  end
end
```

## CRITICAL: Capybara Waiting in Tests

**NEVER use `sleep` in Capybara system tests.** Capybara has built-in intelligent waiting.

**DO NOT:**
```ruby
click_button 'Save'
sleep 0.5  # ❌ WRONG - flaky and slow
expect(page).to have_content('Saved')
```

**DO:**
```ruby
click_button 'Save'
expect(page).to have_content('Saved')  # ✅ Capybara waits automatically

# For AJAX updates, use element expectations:
expect(page).to have_css('.progress-bar[aria-valuenow="50"]')  # Waits for change
expect(page.find('#status')).to have_text('Complete')  # Waits for text

# For custom conditions, use have_xpath/have_css with text/count matchers
expect(page).to have_css('.item', count: 5)  # Waits for exactly 5 items
```

Capybara automatically waits (default 2 seconds, configurable) for:
- `find`, `have_content`, `have_css`, `have_xpath`, `have_text`
- All matchers and finders

### Subtle trap: RSpec predicate matchers and attribute reads do NOT wait

`sleep` is not the only source of flakiness. **RSpec predicate matchers and
snapshot attribute reads on a Capybara node read the DOM exactly once — they do
NOT poll.** After an animation (jQuery `slideUp`/`slideToggle`, fades, CSS
transitions) or any async DOM update, they will observe the *pre-transition*
state and fail intermittently.

**DO NOT** (these snapshot state once, no retry):
```ruby
toggle.click
expect(child_list).not_to be_visible            # ❌ be_visible = one-shot predicate
expect(toggle[:class]).to include('collapsed')  # ❌ [:class] read once
expect(card['aria-expanded']).to eq('false')    # ❌ attribute read once
```

**DO** — assert through a waiting Capybara matcher first, so the animation
settles before you read any snapshot values:
```ruby
toggle.click
# have_css with a visibility filter polls until the element is actually hidden:
expect(cwrapper).to have_css('ul.toclist', visible: :hidden)   # ✅ waits
# Only NOW read snapshot attributes — the DOM has settled:
expect(toggle[:class]).to include('collapsed')
expect(card['aria-expanded']).to eq('false')
```

Use `visible: :visible` / `visible: :hidden` on `have_css`/`have_selector` to
wait for visibility changes. Reach for `matches_css?`/`match_selector` when you
must wait on a specific element's class. **Never** gate correctness on a bare
`be_visible`, `[:attr]`, or `['aria-*']` read immediately after an interaction.

**Remember**: A feature without tests is an incomplete feature.
