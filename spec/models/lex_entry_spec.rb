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

    describe '#sync_works_checklist!' do
      before do
        entry.start_verification!('test@example.com')
      end

      context 'when works are added' do
        it 'adds new works to the checklist' do
          initial_items = entry.verification_progress.dig('checklist', 'works', 'items')
          expect(initial_items).to eq({})

          work = create(:lex_person_work, person: person, title: 'New Work')
          entry.sync_works_checklist!

          updated_items = entry.verification_progress.dig('checklist', 'works', 'items')
          expect(updated_items.size).to eq(1)
          expect(updated_items[work.id.to_s]).to eq({ 'verified' => false, 'notes' => '' })
        end
      end

      context 'when works are deleted' do
        let!(:work1) { create(:lex_person_work, person: person, title: 'Work 1') }
        let!(:work2) { create(:lex_person_work, person: person, title: 'Work 2') }

        before do
          entry.sync_works_checklist!
        end

        it 'removes deleted works from the checklist' do
          expect(entry.verification_progress.dig('checklist', 'works', 'items').size).to eq(2)

          work1.destroy!
          entry.sync_works_checklist!

          updated_items = entry.verification_progress.dig('checklist', 'works', 'items')
          expect(updated_items.size).to eq(1)
          expect(updated_items[work2.id.to_s]).to be_present
          expect(updated_items[work1.id.to_s]).to be_nil
        end
      end

      context 'when works are verified and then deleted' do
        let!(:work1) { create(:lex_person_work, person: person, title: 'Work 1') }
        let!(:work2) { create(:lex_person_work, person: person, title: 'Work 2') }

        before do
          entry.sync_works_checklist!
          entry.update_checklist_item("works.items.#{work1.id}", true, '')
          entry.update_checklist_item("works.items.#{work2.id}", true, '')
        end

        it 'auto-verifies collection when all works verified' do
          expect(entry.verification_progress.dig('checklist', 'works', 'verified')).to be true
        end

        it 'removes auto-verification when a verified work is deleted' do
          work1.destroy!
          entry.sync_works_checklist!

          # Collection should still be verified if all remaining items are verified
          expect(entry.verification_progress.dig('checklist', 'works', 'verified')).to be true
        end
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
end
