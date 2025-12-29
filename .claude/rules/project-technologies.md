# Project Technologies and Preferred Tools

## Required Technologies

* **Views**: We use HAML for views, not ERB
* **Testing Framework**: We use RSpec for testing, not minitest
* **Integration Tests**: We use Capybara for integration tests of real usage scenarios
* **Internationalization**: We use Rails I18n for all user-visible messages and UI labels
  - If you add a new message, make sure to create appropriate entries in both `config/locales/he.yml` and `config/locales/en.yml`
