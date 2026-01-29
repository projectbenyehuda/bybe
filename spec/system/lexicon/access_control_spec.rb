# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon access control' do
  let!(:published_person) do
    create(:lex_person, bio: 'Published bio')
  end

  let!(:published_entry) do
    create(:lex_entry,
           title: 'Published Person',
           lex_item: published_person,
           status: :published)
  end

  let!(:draft_person) do
    create(:lex_person, bio: 'Draft bio')
  end

  let!(:draft_entry) do
    create(:lex_entry,
           title: 'Draft Person',
           lex_item: draft_person,
           status: :draft)
  end

  describe 'unauthenticated users' do
    context 'entries controller' do
      it 'can access published entry show page' do
        visit lexicon_entry_path(published_entry)

        expect(page).to have_content('Published Person')
        expect(page).to have_content('Published bio')
      end

      it 'cannot access draft entry show page' do
        visit lexicon_entry_path(draft_entry)

        # Should be redirected or show error
        expect(page).not_to have_content('Draft Person')
        expect(page).not_to have_content('Draft bio')
      end

      it 'cannot access entries index (admin) page' do
        visit lexicon_entries_path

        # Should be redirected or show error
        expect(page.current_path).not_to eq(lexicon_entries_path)
      end

      it 'cannot access entry edit page' do
        visit edit_lexicon_entry_path(published_entry)

        # Should be redirected or show error
        expect(page.current_path).not_to eq(edit_lexicon_entry_path(published_entry))
      end
    end
  end

  describe 'authenticated users with edit_lexicon permission' do
    before do
      login_as_lexicon_editor
    end

    context 'entries controller' do
      it 'can access published entry show page' do
        visit lexicon_entry_path(published_entry)

        expect(page).to have_content('Published Person')
        expect(page).to have_content('Published bio')
      end

      it 'can access draft entry show page' do
        visit lexicon_entry_path(draft_entry)

        expect(page).to have_content('Draft Person')
        expect(page).to have_content('Draft bio')
      end

      it 'can access entries index (admin) page' do
        visit lexicon_entries_path

        expect(page).to have_content('Published Person')
        expect(page).to have_content('Draft Person')
      end

      it 'can access entry edit page' do
        visit edit_lexicon_entry_path(published_entry)

        expect(page).to have_current_path(edit_lexicon_entry_path(published_entry))
      end
    end
  end

  describe 'authenticated users WITHOUT edit_lexicon permission' do
    before do
      # Create a regular editor user without edit_lexicon permission
      user = create(:user, editor: true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      # Don't mock require_editor to let it actually check permissions
    end

    context 'entries controller' do
      it 'can access published entry show page' do
        visit lexicon_entry_path(published_entry)

        expect(page).to have_content('Published Person')
        expect(page).to have_content('Published bio')
      end

      it 'cannot access draft entry show page' do
        visit lexicon_entry_path(draft_entry)

        # Should be redirected or show error
        expect(page).not_to have_content('Draft Person')
      end

      it 'cannot access entries index (admin) page' do
        visit lexicon_entries_path

        # Should be redirected or show error
        expect(page.current_path).not_to eq(lexicon_entries_path)
      end

      it 'cannot access entry edit page' do
        visit edit_lexicon_entry_path(published_entry)

        # Should be redirected or show error
        expect(page.current_path).not_to eq(edit_lexicon_entry_path(published_entry))
      end
    end
  end
end
