# frozen_string_literal: true

require 'rails_helper'

# Managing the sub-headings within the work-type sections of a person's works (שירה ופרוזה, עיון
# under the original works, ...), from the entry editor's works tab and from the verification
# workbench. See LexPersonWorkGroup.
RSpec.describe 'Works sub-headings', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:person) { create(:lex_person, gender: :female) }
  let!(:entry) { create(:lex_entry, title: 'חמוטל בר-יוסף', lex_item: person, status: :draft) }
  let!(:ungrouped) do
    create(:lex_person_work, person: person, work_type: :original, title: 'לולא היה עלי למהר', seqno: 1)
  end

  def open_works_tab
    visit "/lex/entries/#{entry.id}/edit"
    find('#works_tab').click
    expect(page).to have_css('#works ul.works-bucket', wait: 10)
  end

  def section(work_type)
    find("#works .works-section[data-work-type='#{work_type}']")
  end

  # SortableJS registers itself on the element, so Sortable.get is a direct check that the pane's
  # inline script ran and wired up dragging on the DOM currently on the page.
  def sortables_wired?
    page.evaluate_script(<<~JS)
      (function() {
        var lists = document.querySelectorAll('#works ul.works-bucket');
        return !!window.Sortable && lists.length > 0 &&
          Array.prototype.every.call(lists, function(list) { return !!Sortable.get(list); });
      })()
    JS
  end

  it 'adds a sub-heading to a section, and keeps dragging wired up after the pane reloads' do
    open_works_tab
    expect(sortables_wired?).to be true

    accept_prompt(with: 'עריכה מדעית') { section('edited').find('a.add-work-group').click }

    expect(page).to have_css(".works-section[data-work-type='edited'] .work-group-block",
                             text: 'עריכה מדעית', wait: 5)
    expect(person.work_groups.reload.map { |g| [g.work_type, g.title] }).to eq([['edited', 'עריכה מדעית']])
    expect(sortables_wired?).to be true
  end

  context 'with an existing sub-heading' do
    let!(:group) { create(:lex_person_work_group, person: person, title: 'עיון') }
    let!(:grouped) { create(:lex_person_work, person: person, work_group: group, title: 'מבוא לדקאדנס', seqno: 2) }

    it 'shows the sub-heading in its section, with its work under it' do
      open_works_tab

      within section('original').find('.work-group-block') do
        expect(page).to have_css('.heading-title', text: 'עיון')
        expect(page).to have_css('ul.works-bucket li', text: 'מבוא לדקאדנס')
      end
    end

    it 'renames the sub-heading' do
      open_works_tab
      accept_prompt(with: 'מחקר') { find('#works .rename-work-group').click }

      expect(page).to have_css('#works .work-group-block .heading-title', text: 'מחקר', wait: 5)
      expect(group.reload.title).to eq('מחקר')
    end

    it 'moves the sub-heading, works and all, to another section' do
      open_works_tab
      find('#works select.move-work-group').select(LexPersonWork.human_enum_name(:work_type, 'edited'))

      expect(section('edited')).to have_css('.work-group-block', text: 'מבוא לדקאדנס', wait: 5)
      expect(grouped.reload).to have_attributes(work_type: 'edited', work_group: group)
    end

    it 'removes the sub-heading, keeping its works in the section' do
      open_works_tab
      accept_confirm { find('#works .delete-work-group').click }

      expect(page).to have_no_css('#works .work-group-block', wait: 5)
      expect(page).to have_css('#works_original li', text: 'מבוא לדקאדנס')
      expect(grouped.reload.work_group).to be_nil
    end

    it 'puts a work under the sub-heading from its edit form' do
      open_works_tab
      find("#work_#{ungrouped.id} .edit-person-work").click
      expect(page).to have_css('#generalDlg.show', wait: 5)

      within '#generalDlg' do
        select 'עיון', from: 'lex_person_work[lex_person_work_group_id]'
        click_link_or_button I18n.t(:save)
      end

      expect(page).to have_css("ul#works_group_#{group.id} li", text: 'לולא היה עלי למהר', wait: 5)
      expect(ungrouped.reload.work_group).to eq(group)
    end

    # Ingest files every unrecognized legacy header under the original works, so the workbench is
    # where a sub-heading subdividing another section gets moved there.
    it 'moves the sub-heading to another section from the verification workbench' do
      visit lexicon_verification_path(entry)
      find('#section-works select.verification-move-work-group')
        .select(LexPersonWork.human_enum_name(:work_type, 'edited'))

      expect(page).to have_css('#section-works .work-type-heading',
                               text: LexPersonWork.human_enum_name(:work_type, 'edited'), wait: 8)
      expect(grouped.reload).to have_attributes(work_type: 'edited', work_group: group)
    end
  end
end
