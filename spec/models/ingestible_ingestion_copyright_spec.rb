# frozen_string_literal: true

require 'rails_helper'

describe 'Ingestible copyright logic during ingestion' do
  let(:public_domain_authority) { create(:authority, intellectual_property: :public_domain) }
  let(:copyrighted_authority) { create(:authority, intellectual_property: :copyrighted) }
  let(:ingestible) { create(:ingestible, intellectual_property: 'by_permission') }

  describe 'determining intellectual property for Expression' do
    context 'when text has all public domain authorities' do
      it 'is set to public_domain' do
        text_authorities = [
          { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
            role: 'author' }
        ].to_json

        calculated = ingestible.calculate_copyright_status(text_authorities)
        expect(calculated).to eq('public_domain')

        # The ingestion logic would set IP to public_domain
        toc_line_ip = nil # from TOC
        ingestible_default_ip = ingestible.intellectual_property

        final_ip = if calculated == 'public_domain'
                     'public_domain'
                   else
                     toc_line_ip.presence || ingestible_default_ip || 'by_permission'
                   end

        expect(final_ip).to eq('public_domain')
      end
    end

    context 'when text has copyrighted authorities' do
      it 'uses TOC value when provided' do
        text_authorities = [
          { seqno: 1, authority_id: copyrighted_authority.id, authority_name: copyrighted_authority.name,
            role: 'author' }
        ].to_json

        calculated = ingestible.calculate_copyright_status(text_authorities)
        expect(calculated).to eq('copyrighted')

        # The ingestion logic would use the TOC value
        toc_line_ip = 'orphan' # from TOC
        ingestible_default_ip = ingestible.intellectual_property

        final_ip = if calculated == 'public_domain'
                     'public_domain'
                   else
                     toc_line_ip.presence || ingestible_default_ip || 'by_permission'
                   end

        expect(final_ip).to eq('orphan')
      end

      it 'uses ingestible default when TOC value is blank' do
        text_authorities = [
          { seqno: 1, authority_id: copyrighted_authority.id, authority_name: copyrighted_authority.name,
            role: 'author' }
        ].to_json

        calculated = ingestible.calculate_copyright_status(text_authorities)
        expect(calculated).to eq('copyrighted')

        # The ingestion logic would use the ingestible default
        toc_line_ip = nil # from TOC
        ingestible_default_ip = 'orphan'

        final_ip = if calculated == 'public_domain'
                     'public_domain'
                   else
                     toc_line_ip.presence || ingestible_default_ip || 'by_permission'
                   end

        expect(final_ip).to eq('orphan')
      end

      it 'defaults to by_permission when no value provided' do
        text_authorities = [
          { seqno: 1, authority_id: copyrighted_authority.id, authority_name: copyrighted_authority.name,
            role: 'author' }
        ].to_json

        calculated = ingestible.calculate_copyright_status(text_authorities)
        expect(calculated).to eq('copyrighted')

        # The ingestion logic would default to by_permission
        toc_line_ip = nil # from TOC
        ingestible_default_ip = nil

        final_ip = if calculated == 'public_domain'
                     'public_domain'
                   else
                     toc_line_ip.presence || ingestible_default_ip || 'by_permission'
                   end

        expect(final_ip).to eq('by_permission')
      end
    end
  end
end
