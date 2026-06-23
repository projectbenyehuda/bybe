# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LexEntry, type: :model do
  describe '#profile_image' do
    let(:entry) { create(:lex_entry) }

    context 'when no profile_image_id is set' do
      it 'returns nil' do
        expect(entry.profile_image).to be_nil
      end
    end

    context 'when profile_image_id is set' do
      it 'returns the attachment with that ID' do
        # Attach a file to the entry
        entry.attachments.attach(
          io: StringIO.new('test image content'),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )

        attachment = entry.attachments.first
        entry.update!(profile_image_id: attachment.id)

        expect(entry.profile_image).to eq(attachment)
      end
    end
  end

  describe 'works verification' do
    let(:person) { create(:lex_person) }
    let(:entry) { create(:lex_entry, lex_item: person) }

    describe '#build_checklist' do
      context 'when person has works' do
        let!(:work1) { create(:lex_person_work, person: person, title: 'Work 1') }
        let!(:work2) { create(:lex_person_work, person: person, title: 'Work 2') }

        it 'creates works as a collection with individual items' do
          entry.start_verification!('test@example.com')
          checklist = entry.verification_progress['checklist']

          expect(checklist['works']).to be_present
          expect(checklist['works']['verified']).to be false
          expect(checklist['works']['items']).to be_a(Hash)
          expect(checklist['works']['items'].size).to eq(2)
          expect(checklist['works']['items'][work1.id.to_s]).to eq({ 'verified' => false, 'notes' => '' })
          expect(checklist['works']['items'][work2.id.to_s]).to eq({ 'verified' => false, 'notes' => '' })
        end
      end

      context 'when person has no works' do
        it 'creates works collection with empty items' do
          entry.start_verification!('test@example.com')
          checklist = entry.verification_progress['checklist']

          expect(checklist['works']).to be_present
          expect(checklist['works']['items']).to eq({})
        end
      end
    end

    describe '#add_work_to_checklist!' do
      before do
        entry.start_verification!('test@example.com')
      end

      it 'adds the work ID to checklist items' do
        work = create(:lex_person_work, person: person, title: 'New Work')
        entry.add_work_to_checklist!(work.id)

        items = entry.reload.verification_progress.dig('checklist', 'works', 'items')
        expect(items[work.id.to_s]).to eq({ 'verified' => false, 'notes' => '' })
      end

      it 'is idempotent when work already exists in checklist' do
        work = create(:lex_person_work, person: person, title: 'Existing Work')
        entry.add_work_to_checklist!(work.id)
        entry.update_checklist_item("works.items.#{work.id}", true)
        entry.add_work_to_checklist!(work.id)

        items = entry.reload.verification_progress.dig('checklist', 'works', 'items')
        expect(items[work.id.to_s]['verified']).to be true
      end

      it 'does nothing when verification_progress is blank' do
        entry.update_column(:verification_progress, nil)
        work = create(:lex_person_work, person: person, title: 'New Work')
        expect { entry.add_work_to_checklist!(work.id) }.not_to raise_error
      end

      context 'when called on a stale instance after a concurrent update_checklist_item' do
        it 'does not overwrite the committed change (with_lock prevents lost update)' do
          stale_entry = described_class.find(entry.id)

          entry.update_checklist_item('date_of_manual_update', true)

          expect(stale_entry.verification_progress.dig('checklist', 'date_of_manual_update', 'verified')).to be false

          work = create(:lex_person_work, person: person, title: 'New Work')
          stale_entry.add_work_to_checklist!(work.id)

          expect(entry.reload.verification_progress.dig('checklist', 'date_of_manual_update', 'verified')).to be true
        end
      end
    end

    describe '#remove_work_from_checklist!' do
      let!(:work1) { create(:lex_person_work, person: person, title: 'Work 1') }
      let!(:work2) { create(:lex_person_work, person: person, title: 'Work 2') }

      before do
        person.reload
        entry.start_verification!('test@example.com')
      end

      it 'removes the work ID from checklist items' do
        work1.destroy!
        entry.remove_work_from_checklist!(work1.id)

        items = entry.reload.verification_progress.dig('checklist', 'works', 'items')
        expect(items[work1.id.to_s]).to be_nil
        expect(items[work2.id.to_s]).to be_present
      end

      it 'does nothing when the work ID is not in the checklist' do
        expect { entry.remove_work_from_checklist!(999_999) }.not_to raise_error
      end

      it 'auto-verifies collection when all remaining works are verified' do
        entry.update_checklist_item("works.items.#{work1.id}", true)
        entry.update_checklist_item("works.items.#{work2.id}", true)

        work1.destroy!
        entry.remove_work_from_checklist!(work1.id)

        expect(entry.reload.verification_progress.dig('checklist', 'works', 'verified')).to be true
      end
    end

    describe '#verification_percentage' do
      let!(:work1) { create(:lex_person_work, person: person, title: 'Work 1') }
      let!(:work2) { create(:lex_person_work, person: person, title: 'Work 2') }

      before do
        person.reload # Reload to get the newly created works
        entry.start_verification!('test@example.com')
      end

      it 'includes individual works in percentage calculation' do
        # Reload to ensure we have the latest checklist
        entry.reload

        # Initially, nothing is verified, but should have items to verify
        initial_percentage = entry.verification_percentage
        expect(initial_percentage).to eq(0) # 0% because nothing is verified yet

        # Verify one work
        entry.update_checklist_item("works.items.#{work1.id}", true, '')
        percentage_after_one = entry.verification_percentage

        # Verify second work
        entry.update_checklist_item("works.items.#{work2.id}", true, '')
        percentage_after_two = entry.verification_percentage

        # Percentage should increase as works are verified
        expect(percentage_after_two).to be > percentage_after_one
        expect(percentage_after_one).to be > initial_percentage
      end

      it 'counts works items separately from collection' do
        checklist = entry.verification_progress['checklist']
        total_items = 0

        # Count non-collection items
        %w(title life_years bio description toc az_navbar attachments).each do |key|
          total_items += 1 if checklist[key]
        end

        # Count collection items
        %w(citations links works).each do |collection|
          next unless checklist[collection]&.dig('items')

          total_items += checklist[collection]['items'].size
        end

        # Should have 2 works items
        expect(checklist.dig('works', 'items').size).to eq(2)
      end
    end

    describe 'auto-verify collections' do
      let!(:work1) { create(:lex_person_work, person: person, title: 'Work 1') }
      let!(:work2) { create(:lex_person_work, person: person, title: 'Work 2') }

      before do
        entry.start_verification!('test@example.com')
      end

      it 'auto-verifies works collection when all individual works are verified' do
        expect(entry.verification_progress.dig('checklist', 'works', 'verified')).to be false

        entry.update_checklist_item("works.items.#{work1.id}", true, '')
        expect(entry.verification_progress.dig('checklist', 'works', 'verified')).to be false

        entry.update_checklist_item("works.items.#{work2.id}", true, '')
        expect(entry.verification_progress.dig('checklist', 'works', 'verified')).to be true
      end

      it 'removes auto-verification when a work is unchecked' do
        # Verify all works
        entry.update_checklist_item("works.items.#{work1.id}", true, '')
        entry.update_checklist_item("works.items.#{work2.id}", true, '')
        expect(entry.verification_progress.dig('checklist', 'works', 'verified')).to be true

        # Unverify one work
        entry.update_checklist_item("works.items.#{work1.id}", false, '')
        expect(entry.verification_progress.dig('checklist', 'works', 'verified')).to be false
      end
    end

    describe '#mark_all_works_verified!' do
      let!(:work1) { create(:lex_person_work, person: person, title: 'Work 1') }
      let!(:work2) { create(:lex_person_work, person: person, title: 'Work 2') }
      let!(:work3) { create(:lex_person_work, person: person, title: 'Work 3') }

      before do
        person.reload
        entry.start_verification!('test@example.com')
      end

      it 'marks all individual works as verified' do
        entry.mark_all_works_verified!('Verified all works')

        checklist = entry.verification_progress['checklist']
        expect(checklist.dig('works', 'items', work1.id.to_s, 'verified')).to be true
        expect(checklist.dig('works', 'items', work2.id.to_s, 'verified')).to be true
        expect(checklist.dig('works', 'items', work3.id.to_s, 'verified')).to be true
      end

      it 'marks the works section itself as verified' do
        entry.mark_all_works_verified!('Verified all works')

        checklist = entry.verification_progress['checklist']
        expect(checklist.dig('works', 'verified')).to be true
      end

      it 'sets notes on all individual works' do
        entry.mark_all_works_verified!('All verified')

        checklist = entry.verification_progress['checklist']
        expect(checklist.dig('works', 'items', work1.id.to_s, 'notes')).to eq('All verified')
        expect(checklist.dig('works', 'items', work2.id.to_s, 'notes')).to eq('All verified')
        expect(checklist.dig('works', 'items', work3.id.to_s, 'notes')).to eq('All verified')
      end

      it 'sets notes on the works section' do
        entry.mark_all_works_verified!('Section verified')

        checklist = entry.verification_progress['checklist']
        expect(checklist.dig('works', 'notes')).to eq('Section verified')
      end

      it 'handles entries with no works gracefully' do
        person_no_works = create(:lex_person)
        entry_no_works = create(:lex_entry, lex_item: person_no_works)
        entry_no_works.start_verification!('test@example.com')

        expect { entry_no_works.mark_all_works_verified! }.not_to raise_error

        checklist = entry_no_works.verification_progress['checklist']
        expect(checklist.dig('works', 'verified')).to be true
        expect(checklist.dig('works', 'items')).to eq({})
      end
    end
  end

  describe 'external_identifiers verification' do
    let(:person) { create(:lex_person) }
    let(:entry) { create(:lex_entry, lex_item: person) }

    describe '#build_checklist' do
      it 'includes external_identifiers in the checklist for LexPerson entries' do
        entry.start_verification!('test@example.com')
        checklist = entry.verification_progress['checklist']

        expect(checklist['external_identifiers']).to eq({ 'verified' => false, 'notes' => '' })
      end

      context 'when entry is a LexPublication' do
        let(:publication) { create(:lex_publication) }
        let(:pub_entry) { create(:lex_entry, lex_item: publication) }

        it 'includes external_identifiers in the checklist for LexPublication entries' do
          pub_entry.start_verification!('test@example.com')
          checklist = pub_entry.verification_progress['checklist']

          expect(checklist['external_identifiers']).to eq({ 'verified' => false, 'notes' => '' })
        end
      end
    end

    describe '#verification_percentage' do
      it 'counts external_identifiers in the percentage calculation' do
        entry.start_verification!('test@example.com')
        percentage_before = entry.verification_percentage

        entry.update_checklist_item('external_identifiers', true, '')
        percentage_after = entry.verification_percentage

        expect(percentage_after).to be > percentage_before
      end
    end

    describe '#update_checklist_item for external_identifiers' do
      before { entry.start_verification!('test@example.com') }

      it 'marks external_identifiers as verified' do
        entry.update_checklist_item('external_identifiers', true, 'Looks good')
        expect(entry.verification_progress.dig('checklist', 'external_identifiers', 'verified')).to be true
        expect(entry.verification_progress.dig('checklist', 'external_identifiers', 'notes')).to eq('Looks good')
      end
    end
  end

  describe '.needs_verification scope' do
    it 'includes draft, verifying, error, and escalated entries' do
      draft_entry     = create(:lex_entry, status: :draft)
      verifying_entry = create(:lex_entry, status: :verifying, verification_progress: { 'checklist' => {} })
      error_entry     = create(:lex_entry, status: :error)
      escalated_entry = create(:lex_entry, status: :escalated, verification_progress: { 'checklist' => {} })
      published_entry = create(:lex_entry, status: :published)
      verified_entry  = create(:lex_entry, status: :verified, verification_progress: { 'checklist' => {} })

      result = described_class.needs_verification
      expect(result).to include(draft_entry, verifying_entry, error_entry, escalated_entry)
      expect(result).not_to include(published_entry, verified_entry)
    end
  end

  describe '#redo_migration_eligible?' do
    it 'is true for draft, verifying, and escalated entries that have a lex_file' do
      %i(draft verifying escalated).each do |status|
        file = create(:lex_file, :person, entry_status: status)
        expect(file.lex_entry.redo_migration_eligible?).to be(true)
      end
    end

    it 'is false for entries in other statuses even with a lex_file' do
      %i(raw migrating error verified published).each do |status|
        file = create(:lex_file, :person, entry_status: status)
        expect(file.lex_entry.redo_migration_eligible?).to be(false)
      end
    end

    it 'is false when the entry has no lex_file' do
      entry = create(:lex_entry, status: :verifying, verification_progress: { 'checklist' => {} })
      expect(entry.redo_migration_eligible?).to be(false)
    end
  end

  describe '#last_content_update' do
    let(:person) { create(:lex_person) }
    let(:entry) { create(:lex_entry, lex_item: person) }

    let(:base_time)   { 3.days.ago.change(usec: 0) }
    let(:newest_time) { 1.day.ago.change(usec: 0) }

    before { entry.update_columns(updated_at: base_time) }

    it 'returns the entry updated_at when nothing else is newer' do
      person.update_columns(updated_at: base_time)
      expect(entry.last_content_update).to eq(base_time)
    end

    it 'returns the lex_item updated_at when it is newest' do
      person.update_columns(updated_at: newest_time)
      expect(entry.last_content_update).to eq(newest_time)
    end

    it 'returns a citation updated_at when it is newest' do
      person.update_columns(updated_at: base_time)
      citation = create(:lex_citation, person: person)
      citation.update_columns(updated_at: newest_time)
      expect(entry.last_content_update).to eq(newest_time)
    end

    it 'returns a work updated_at when it is newest' do
      person.update_columns(updated_at: base_time)
      work = create(:lex_person_work, person: person)
      work.update_columns(updated_at: newest_time)
      expect(entry.last_content_update).to eq(newest_time)
    end

    it 'returns a lex_link updated_at when it is newest' do
      person.update_columns(updated_at: base_time)
      lex_link = create(:lex_link, item: person)
      lex_link.update_columns(updated_at: newest_time)
      expect(entry.last_content_update).to eq(newest_time)
    end

    context 'when syncing updated_at to the computed max' do
      it 'syncs updated_at when constituent is more than 24h newer' do
        person.update_columns(updated_at: newest_time) # 2 days after entry's base_time
        entry.last_content_update
        expect(entry.reload.updated_at).to eq(newest_time)
      end

      it 'does not sync updated_at when constituent is within 24h' do
        within_24h = (base_time + 20.hours).change(usec: 0)
        person.update_columns(updated_at: within_24h)
        entry.last_content_update
        expect(entry.reload.updated_at).to eq(base_time)
      end

      it 'does not sync when entry is already the newest' do
        person.update_columns(updated_at: base_time)
        entry.last_content_update
        expect(entry.reload.updated_at).to eq(base_time)
      end
    end

    context 'when entry has no lex_item' do
      let(:bare_entry) { create(:lex_entry, status: :raw) }

      before { bare_entry.update_columns(updated_at: base_time) }

      it 'returns the entry updated_at' do
        expect(bare_entry.last_content_update).to eq(base_time)
      end
    end

    context 'with a LexPublication entry' do
      let(:publication) { create(:lex_publication) }
      let(:pub_entry) { create(:lex_entry, lex_item: publication) }

      before do
        pub_entry.update_columns(updated_at: base_time)
        publication.update_columns(updated_at: base_time)
      end

      it 'returns publication updated_at when it is newest' do
        publication.update_columns(updated_at: newest_time)
        expect(pub_entry.last_content_update).to eq(newest_time)
      end
    end
  end

  describe '#other_designation' do
    it 'can be read and written' do
      entry = create(:lex_entry, other_designation: 'alias1; alias2')
      expect(entry.reload.other_designation).to eq('alias1; alias2')
    end
  end

  describe '#mark_verified! other_designation copy' do
    let(:person) { create(:lex_person) }
    let(:entry) { create(:lex_entry, lex_item: person) }

    before do
      # Stub verification_complete? so we can test mark_verified! behaviour
      # without going through the full checklist flow.
      allow(entry).to receive(:verification_complete?).and_return(true)
      entry.update!(verification_progress: { 'checklist' => {}, 'overall_notes' => '',
                                             'ready_for_publish' => false })
    end

    context 'when the LexPerson is linked to an Authority with other_designation' do
      let(:authority) { create(:authority, other_designation: 'שם א; שם ב') }

      before { person.update!(authority: authority) }

      it 'copies other_designation from the Authority onto the entry' do
        entry.mark_verified!
        expect(entry.reload.other_designation).to eq('שם א; שם ב')
      end

      it 'sets status to published' do
        entry.mark_verified!
        expect(entry.reload).to be_status_published
      end
    end

    context 'when the LexPerson has no linked Authority' do
      it 'leaves other_designation unchanged' do
        entry.mark_verified!
        expect(entry.reload.other_designation).to be_nil
      end
    end

    context 'when the linked Authority has blank other_designation' do
      let(:authority) { create(:authority, other_designation: '') }

      before { person.update!(authority: authority) }

      it 'does not overwrite other_designation' do
        entry.update!(other_designation: 'existing value')
        entry.mark_verified!
        expect(entry.reload.other_designation).to eq('existing value')
      end
    end

    context 'when the entry belongs to a LexPublication (not LexPerson)' do
      let(:publication) { create(:lex_publication) }
      let(:pub_entry) { create(:lex_entry, lex_item: publication, other_designation: nil) }

      before do
        allow(pub_entry).to receive(:verification_complete?).and_return(true)
        pub_entry.update!(verification_progress: { 'checklist' => {}, 'overall_notes' => '',
                                                   'ready_for_publish' => false })
      end

      it 'does not raise and leaves other_designation nil' do
        expect { pub_entry.mark_verified! }.not_to raise_error
        expect(pub_entry.reload.other_designation).to be_nil
      end
    end
  end
end
