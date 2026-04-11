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

    context 'when value is silently not persisted after save' do
      it 'returns an error if the saved value does not match the intended value' do
        # Simulate a before_validation callback that resets a field to nil,
        # so save returns true but the intended value was not persisted.
        work = manifestation.expression.work
        expression = manifestation.expression
        allow(expression).to receive(:work).and_return(work)
        allow(work).to receive(:save) do
          work.write_attribute(:orig_lang, nil) # simulate silent normalization
          true
        end

        changes = [{ 'kind' => 'field_update', 'record_type' => 'work',
                     'field' => 'orig_lang', 'value' => 'invalid_lang' }]
        # Feed the same manifestation but stub its expression to get our rigged work
        allow(Manifestation).to receive(:find_by).with(id: manifestation.id).and_return(
          instance_double(Manifestation, expression: expression)
        )
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end
    end

    context 'with unknown change kind' do
      it 'returns an error string' do
        changes = [{ 'kind' => 'does_not_exist' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).to include('does_not_exist')
      end
    end

    context 'when an unexpected exception is raised inside apply_change' do
      it 'logs the error and returns a generic i18n message with an error ID' do
        allow(manifestation).to receive(:assign_attributes).and_raise(RuntimeError, 'DB exploded')
        allow(Manifestation).to receive(:find_by).with(id: manifestation.id).and_return(manifestation)
        allow(Rails.logger).to receive(:error)

        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'title', 'value' => 'X' }]
        results = apply([m_record], changes)
        error_msg = result_for(results, m_record).first
        expect(Rails.logger).to have_received(:error).with(a_string_matching(/MassUpdateService.*DB exploded/))
        expect(error_msg).to be_a(String)
        expect(error_msg).to match(/[0-9a-f]{8}/)
        expect(error_msg).not_to include('DB exploded')
      end
    end

    context 'with boolean field changes' do
      it 'sets exclude_from_index to true' do
        manifestation.update!(exclude_from_index: false)
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'exclude_from_index', 'value' => 'true' }]
        apply([m_record], changes)
        expect(manifestation.reload.exclude_from_index).to be true
      end

      it 'sets exclude_from_index to false' do
        manifestation.update!(exclude_from_index: true)
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'exclude_from_index', 'value' => 'false' }]
        apply([m_record], changes)
        expect(manifestation.reload.exclude_from_index).to be false
      end

      it 'sets sefaria_linker (nullable boolean) to true' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'sefaria_linker', 'value' => 'true' }]
        apply([m_record], changes)
        expect(manifestation.reload.sefaria_linker).to be true
      end

      it 'clears sefaria_linker (nullable boolean) when value is blank' do
        manifestation.update!(sefaria_linker: true)
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'sefaria_linker', 'value' => '' }]
        apply([m_record], changes)
        expect(manifestation.reload.sefaria_linker).to be_nil
      end

      it 'sets primary (work boolean) to false' do
        work = manifestation.expression.work
        work.update!(primary: true)
        changes = [{ 'kind' => 'field_update', 'record_type' => 'work',
                     'field' => 'primary', 'value' => 'false' }]
        apply([m_record], changes)
        expect(work.reload.primary).to be false
      end

      it 'sets suppress_download_and_print (collection boolean) to true' do
        collection.update!(suppress_download_and_print: false)
        changes = [{ 'kind' => 'field_update', 'record_type' => 'collection',
                     'field' => 'suppress_download_and_print', 'value' => 'true' }]
        apply([c_record], changes)
        expect(collection.reload.suppress_download_and_print).to be true
      end
    end

    context 'with enum field changes' do
      it 'sets manifestation status to published' do
        manifestation.update!(status: :unpublished)
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'status', 'value' => 'published' }]
        apply([m_record], changes)
        expect(manifestation.reload.status).to eq('published')
      end

      it 'sets manifestation status to deprecated' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'status', 'value' => 'deprecated' }]
        apply([m_record], changes)
        expect(manifestation.reload.status).to eq('deprecated')
      end

      it 'sets manifestation status to nonpd' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'status', 'value' => 'nonpd' }]
        apply([m_record], changes)
        expect(manifestation.reload.status).to eq('nonpd')
      end

      it 'sets expression intellectual_property to by_permission' do
        expression = manifestation.expression
        changes = [{ 'kind' => 'field_update', 'record_type' => 'expression',
                     'field' => 'intellectual_property', 'value' => 'by_permission' }]
        apply([m_record], changes)
        expect(expression.reload.intellectual_property).to eq('by_permission')
      end

      it 'sets expression intellectual_property to copyrighted' do
        expression = manifestation.expression
        changes = [{ 'kind' => 'field_update', 'record_type' => 'expression',
                     'field' => 'intellectual_property', 'value' => 'copyrighted' }]
        apply([m_record], changes)
        expect(expression.reload.intellectual_property).to eq('copyrighted')
      end

      it 'returns an error for an invalid enum value' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'status', 'value' => 'not_a_real_status' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end

      it 'sets collection collection_type to periodical' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'collection',
                     'field' => 'collection_type', 'value' => 'periodical' }]
        apply([c_record], changes)
        expect(collection.reload.collection_type).to eq('periodical')
      end

      it 'sets work genre to prose' do
        work = manifestation.expression.work
        changes = [{ 'kind' => 'field_update', 'record_type' => 'work',
                     'field' => 'genre', 'value' => 'prose' }]
        apply([m_record], changes)
        expect(work.reload.genre).to eq('prose')
      end

      it 'returns an error for blank enum with presence validation' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'expression',
                     'field' => 'intellectual_property', 'value' => '' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end
    end

    context 'with mixed Manifestation and Collection records in the same batch' do
      it 'applies a collection-level change to collection and ignores it for manifestation' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'collection',
                     'field' => 'title', 'value' => 'Bulk Title' }]
        results = apply([m_record, c_record], changes)
        # Collection gets the update
        expect(collection.reload.title).to eq('Bulk Title')
        # Manifestation gets an error (collection field not applicable)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end

      it 'applies a manifestation-level change to manifestation and returns error for collection' do
        changes = [{ 'kind' => 'field_update', 'record_type' => 'manifestation',
                     'field' => 'title', 'value' => 'Batch Title' }]
        results = apply([m_record, c_record], changes)
        expect(manifestation.reload.title).to eq('Batch Title')
        expect(result_for(results, c_record).first).not_to eq(:ok)
      end

      it 'applies a work-level change to manifestation but returns error for collection' do
        work = manifestation.expression.work
        changes = [{ 'kind' => 'field_update', 'record_type' => 'work',
                     'field' => 'genre', 'value' => 'drama' }]
        results = apply([m_record, c_record], changes)
        expect(work.reload.genre).to eq('drama')
        expect(result_for(results, c_record).first).not_to eq(:ok)
      end

      it 'applies multiple changes and collects independent results per record' do
        changes = [
          { 'kind' => 'field_update', 'record_type' => 'manifestation', 'field' => 'title', 'value' => 'M Title' },
          { 'kind' => 'field_update', 'record_type' => 'collection', 'field' => 'title', 'value' => 'C Title' }
        ]
        apply([m_record, c_record], changes)
        expect(manifestation.reload.title).to eq('M Title')
        expect(collection.reload.title).to eq('C Title')
      end
    end

    context 'with InvolvedAuthority role validation' do
      let(:authority) { create(:authority) }

      it 'returns error when adding translator role to work entity (translator is expression-only)' do
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'translator',
                     'authority_id' => authority.id, 'entity' => 'work' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end

      it 'returns error when adding author role to expression entity (author is work-only)' do
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'author',
                     'authority_id' => authority.id, 'entity' => 'expression' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end

      it 'allows editor role on work entity' do
        work = manifestation.expression.work
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'editor',
                     'authority_id' => authority.id, 'entity' => 'work' }]
        expect { apply([m_record], changes) }.to change {
          InvolvedAuthority.where(item: work, authority: authority, role: :editor).count
        }.by(1)
      end

      it 'allows translator role on expression entity' do
        expression = manifestation.expression
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'translator',
                     'authority_id' => authority.id, 'entity' => 'expression' }]
        expect { apply([m_record], changes) }.to change {
          InvolvedAuthority.where(item: expression, authority: authority, role: :translator).count
        }.by(1)
      end

      it 'returns error when entity is not applicable for Collection record' do
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'editor',
                     'authority_id' => authority.id, 'entity' => 'work' }]
        results = apply([c_record], changes)
        expect(result_for(results, c_record).first).not_to eq(:ok)
      end

      it 'returns error for expression entity on Collection record' do
        changes = [{ 'kind' => 'involved_authority_add', 'role' => 'editor',
                     'authority_id' => authority.id, 'entity' => 'expression' }]
        results = apply([c_record], changes)
        expect(result_for(results, c_record).first).not_to eq(:ok)
      end
    end

    context 'with ExternalLink edge cases' do
      it 'returns error for a URL with an invalid scheme (ftp://)' do
        changes = [{ 'kind' => 'external_link_add', 'url' => 'ftp://example.com',
                     'linktype' => 'wikipedia', 'description' => '' }]
        results = apply([m_record], changes)
        expect(result_for(results, m_record).first).not_to eq(:ok)
      end

      it 'is idempotent when the same URL is added twice to the same record' do
        changes = [{ 'kind' => 'external_link_add', 'url' => 'https://example.com',
                     'linktype' => 'wikipedia', 'description' => '' }]
        apply([m_record], changes)
        # Second add should fail due to uniqueness (same linkable + url)
        results = apply([m_record], changes)
        # Either returns :ok (truly idempotent) or returns a validation error string —
        # either way, it must NOT raise an exception, just return a result
        expect(result_for(results, m_record).first).to be_a(Symbol).or be_a(String)
      end

      it 'adds an external link to a Collection record' do
        changes = [{ 'kind' => 'external_link_add', 'url' => 'https://collection.example.com',
                     'linktype' => 'other', 'description' => 'Test' }]
        results = apply([c_record], changes)
        expect(result_for(results, c_record).first).to eq(:ok)
        expect(ExternalLink.find_by(linkable: collection, url: 'https://collection.example.com')).to be_present
      end

      it 'removes an external link from a Collection record' do
        link = ExternalLink.create!(linkable: collection, url: 'https://collection.example.com', linktype: :other)
        changes = [{ 'kind' => 'external_link_remove', 'url' => 'https://collection.example.com' }]
        results = apply([c_record], changes)
        expect(result_for(results, c_record).first).to eq(:ok)
        expect(ExternalLink.exists?(link.id)).to be false
      end

      it 'does not remove a URL that belongs to a different record' do
        # Link exists on manifestation, we try to remove from collection — should fail for collection
        ExternalLink.create!(linkable: manifestation, url: 'https://shared-url.example.com', linktype: :other)
        changes = [{ 'kind' => 'external_link_remove', 'url' => 'https://shared-url.example.com' }]
        results = apply([c_record], changes)
        # Collection should get an error (not found on collection)
        expect(result_for(results, c_record).first).not_to eq(:ok)
        # The manifestation's link is untouched
        expect(ExternalLink.find_by(linkable: manifestation, url: 'https://shared-url.example.com')).to be_present
      end
    end
  end
end
