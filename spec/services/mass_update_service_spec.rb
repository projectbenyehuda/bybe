# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MassUpdateService do
  let(:manifestation) { create(:manifestation, title: 'Original Title') }
  let(:collection) { create(:collection, title: 'Original Collection', collection_type: :volume) }

  let(:m_record) { { 'type' => 'Manifestation', 'id' => manifestation.id } }
  let(:c_record) { { 'type' => 'Collection', 'id' => collection.id } }

  def apply(records, changes)
    described_class.new(records, changes).apply
  end

  def result_for(results, record)
    results[[record['type'], record['id']]]
  end

  describe '#apply' do
    context 'when record does not exist' do
      it 'returns error for all changes' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'title', 'value' => 'X' }]
        results = apply([{ 'type' => 'Manifestation', 'id' => 0 }], changes)
        expect(results[['Manifestation', 0]].first).to eq(I18n.t('admin.mass_update.errors.record_not_found'))
      end
    end

    context 'with field_update changes' do
      it 'updates a manifestation title' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'title',
                     'value' => 'New Title' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record)).to eq([:ok])
        expect(manifestation.reload.title).to eq('New Title')
      end

      it 'updates a manifestation status' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'status',
                     'value' => 'unpublished' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record)).to eq([:ok])
        expect(manifestation.reload.status).to eq('unpublished')
      end

      it 'clears a field when value is blank' do
        manifestation.update!(comment: 'old comment')
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'comment', 'value' => '' }]
        apply([m_record], changes)
        expect(manifestation.reload.comment).to be_nil
      end

      it 'updates an expression field (period)' do
        expression = manifestation.expression
        changes = [{ 'kind' => 'field_update', 'record_type' => 'expression', 'field' => 'period',
                     'value' => 'modern' }]
        apply([m_record], changes)
        expect(expression.reload.period).to eq('modern')
      end

      it 'updates a work field (genre)' do
        work = manifestation.expression.work
        changes = [{ 'kind' => 'field_update', 'record_type' => 'work', 'field' => 'genre', 'value' => 'poetry' }]
        apply([m_record], changes)
        expect(work.reload.genre).to eq('poetry')
      end

      it 'updates a collection field' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'collection', 'field' => 'title',
                     'value' => 'New Name' }]
        results = apply([c_record], changes)
        expect(result_for(results, c_record)).to eq([:ok])
        expect(collection.reload.title).to eq('New Name')
      end

      it 'returns error when work field applied to collection' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'work', 'field' => 'genre', 'value' => 'poetry' }]
        results = apply([c_record], changes)
        expect(result_for(results, c_record).first).not_to eq(:ok)
      end

      it 'returns error for disallowed field' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'markdown',
                     'value' => 'x' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end
    end

    context 'with involved_authority changes' do
      let(:authority) { create(:authority) }

      it 'adds an involved authority to the work' do
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'editor', 'authority_id' => authority.id,
                     'entity' => 'work' }]
        work = manifestation.expression.work
        expect { apply([m_record], changes) }.to change {
          InvolvedAuthority.where(item: work, authority: authority).count
        }.by(1)
      end

      it 'is idempotent for add (find_or_create)' do
        work = manifestation.expression.work
        InvolvedAuthority.create!(item: work, authority: authority, role: :editor)
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'editor', 'authority_id' => authority.id,
                     'entity' => 'work' }]
        expect { apply([m_record], changes) }.not_to(change(InvolvedAuthority, :count))
      end

      it 'adds an involved authority to the expression' do
        expression = manifestation.expression
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'translator', 'authority_id' => authority.id,
                     'entity' => 'expression' }]
        expect { apply([m_record], changes) }.to change {
          InvolvedAuthority.where(item: expression, authority: authority).count
        }.by(1)
      end

      it 'removes an existing involved authority' do
        work = manifestation.expression.work
        ia = InvolvedAuthority.create!(item: work, authority: authority, role: :editor)
        changes = [{ 'kind' => 'involved_authority_remove', 'role' => 'editor', 'authority_id' => authority.id,
                     'entity' => 'work' }]
        expect { apply([m_record], changes) }.to change { InvolvedAuthority.exists?(ia.id) }.from(true).to(false)
      end

      it 'returns error when removing non-existent involvement' do
        changes = [{ 'kind' => 'involved_authority_remove', 'role' => 'editor', 'authority_id' => authority.id,
                     'entity' => 'work' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end

      it 'returns error for missing authority_id' do
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'editor', 'authority_id' => 0, 'entity' => 'work' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end
    end

    context 'with external_link changes' do
      it 'adds an external link' do
        changes = [{ 'kind' => 'external_link_add', 'url' => 'https://example.com', 'linktype' => 'wikipedia',
                     'description' => 'Test' }]
        expect { apply([m_record], changes) }.to change(ExternalLink, :count).by(1)
        link = ExternalLink.last
        expect(link.url).to eq('https://example.com')
        expect(link.linkable).to eq(manifestation)
        expect(link).to be_status_approved
      end

      it 'removes an external link by URL' do
        link = ExternalLink.create!(linkable: manifestation, url: 'https://example.com', linktype: :wikipedia)
        changes = [{ 'kind' => 'external_link_remove', 'url' => 'https://example.com' }]
        expect { apply([m_record], changes) }.to change { ExternalLink.exists?(link.id) }.from(true).to(false)
      end

      it 'returns error when removing non-existent link' do
        changes = [{ 'kind' => 'external_link_remove', 'url' => 'https://no-such-url.com' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end
    end

    context 'with multiple records and changes' do
      let(:manifestation2) { create(:manifestation, title: 'Second Manifestation') }
      let(:m_record2) { { 'type' => 'Manifestation', 'id' => manifestation2.id } }

      it 'applies all changes to all records independently' do
        changes = [
          { 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'title', 'value' => 'Updated' },
          { 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'comment', 'value' => 'Note' }
        ]
        apply([m_record, m_record2], changes)
        expect(manifestation.reload.title).to eq('Updated')
        expect(manifestation2.reload.title).to eq('Updated')
        expect(manifestation.reload.comment).to eq('Note')
      end

      it 'collects errors without aborting other records' do
        bad_record = { 'type' => 'Manifestation', 'id' => 0 }
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'title', 'value' => 'OK' }]
        apply([m_record, bad_record, m_record2], changes)
        expect(manifestation.reload.title).to eq('OK')
        expect(manifestation2.reload.title).to eq('OK')
      end
    end

    context 'with unknown change kind' do
      it 'returns an error string' do
        changes = [{ 'kind' => 'does_not_exist' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).to include('does_not_exist')
      end
    end
  end
end
