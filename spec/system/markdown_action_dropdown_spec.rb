# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Markdown editing action dropdown', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    # System specs require stubbing at the controller level
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # rubocop:enable RSpec/AnyInstance
  end

  let(:user) { create(:user, :edit_catalog) }
  let(:markdown) { "שורה ראשונה\nמילה-מחוברת\n" }
  let!(:manifestation) { create(:manifestation, status: :published, markdown: markdown) }

  # Places the caret at the very end of the markdown textarea.
  def caret_to_end
    page.execute_script(<<~JS)
      var el = document.querySelector('#markdown');
      el.focus();
      el.selectionStart = el.selectionEnd = el.value.length;
    JS
  end

  # Places the caret inside the markdown textarea at the given offset, selecting
  # length characters from there (length 0 leaves nothing selected).
  def select_range(start, length)
    page.execute_script(<<~JS, start, length)
      var el = document.querySelector('#markdown');
      el.focus();
      el.selectionStart = arguments[0];
      el.selectionEnd = arguments[0] + arguments[1];
    JS
  end

  def select_action(label)
    find('.js-markdown-action').find('option', text: label).select_option
  end

  def apply_action(label)
    select_action(label)
    find('.js-markdown-action-apply').click
  end

  def selected_action
    find('.js-markdown-action').value
  end

  it 'replaces the old button strip with a single dropdown and action button' do
    visit manifestation_edit_path(manifestation)

    expect(page).to have_css('.js-markdown-action', wait: 5)
    expect(page).to have_css('.js-markdown-action-apply')

    # every action the old buttons offered is now an option
    expect(all('.js-markdown-action option').map(&:text)).to eq(
      [I18n.t(:add_stanza_break), I18n.t(:add_angled_brackets), I18n.t(:remove_angled_brackets),
       I18n.t(:minuses_to_makafim), I18n.t(:indent), I18n.t(:center_text), I18n.t(:tidy_footnote_dirs)]
    )

    # the individual buttons are gone
    %w(add_stanza_break add_angled_brackets remove_angled_brackets minuses_to_makafim add_indent).each do |old_id|
      expect(page).to have_no_css("##{old_id}")
    end
  end

  it 'performs the selected action and keeps the selection so it can be repeated' do
    visit manifestation_edit_path(manifestation)
    expect(page).to have_css('.js-markdown-action', wait: 5)

    caret_to_end
    apply_action(I18n.t(:indent))
    expect(find('#markdown').value).to end_with('&emsp;')

    # the dropdown must still hold the same action, so clicking again just repeats it
    expect(selected_action).to eq('add_indent')
    find('.js-markdown-action-apply').click
    expect(find('#markdown').value).to end_with('&emsp;&emsp;')
    expect(selected_action).to eq('add_indent')
  end

  it 'dispatches a different action when the selection changes' do
    visit manifestation_edit_path(manifestation)
    expect(page).to have_css('.js-markdown-action', wait: 5)

    caret_to_end
    apply_action(I18n.t(:add_stanza_break))
    expect(find('#markdown').value).to end_with("\n>\n<br />\n>\n")

    accept_alert do
      apply_action(I18n.t(:minuses_to_makafim))
    end
    expect(find('#markdown').value).to include('מילה־מחוברת')
    expect(selected_action).to eq('minuses_to_makafim')
  end

  describe 'the centering action' do
    it 'wraps the whole caret line when nothing is selected' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('.js-markdown-action', wait: 5)

      # caret parked mid-way into the second line, nothing selected
      select_range(markdown.index('מילה') + 2, 0)
      apply_action(I18n.t(:center_text))

      expect(find('#markdown').value).to eq("שורה ראשונה\n<center>מילה-מחוברת</center>\n")
    end

    it 'wraps precisely the selected text when there is a selection' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('.js-markdown-action', wait: 5)

      # only the first word of the first line is selected
      select_range(markdown.index('שורה'), 'שורה'.length)
      apply_action(I18n.t(:center_text))

      expect(find('#markdown').value).to eq("<center>שורה</center> ראשונה\nמילה-מחוברת\n")
    end
  end

  it 'does not submit the form when the action button is clicked' do
    visit manifestation_edit_path(manifestation)
    expect(page).to have_css('.js-markdown-action', wait: 5)

    caret_to_end
    apply_action(I18n.t(:indent))
    # still on the edit page — the button must not act as a submit button
    expect(page).to have_current_path(manifestation_edit_path(manifestation))
    expect(find('#markdown').value).to end_with('&emsp;')
  end
end
