# frozen_string_literal: true

require 'rails_helper'

describe Ingestible, 'copyright calculation' do
  let(:ingestible) { create(:ingestible) }
  let(:public_domain_authority) { create(:authority, intellectual_property: :public_domain) }
  let(:copyrighted_authority) { create(:authority, intellectual_property: :copyrighted) }
  let(:orphan_authority) { create(:authority, intellectual_property: :orphan) }
  let(:permission_authority) { create(:authority, intellectual_property: :permission_for_all) }

  describe '#calculate_copyright_status' do
    context 'when all authorities are public domain' do
      it 'returns public_domain' do
        ingestible.default_authorities = [
          { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
            role: 'author' }
        ].to_json

        # Empty string means use defaults (not explicit empty array)
        text_authorities = ''

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('public_domain')
      end
    end

    context 'when at least one authority is copyrighted' do
      it 'returns copyrighted' do
        ingestible.default_authorities = [
          { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
            role: 'author' }
        ].to_json

        text_authorities = [
          { seqno: 1, authority_id: copyrighted_authority.id, authority_name: copyrighted_authority.name,
            role: 'translator' }
        ].to_json

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('copyrighted')
      end
    end

    context 'when at least one authority is orphan' do
      it 'returns copyrighted' do
        ingestible.default_authorities = [
          { seqno: 1, authority_id: orphan_authority.id, authority_name: orphan_authority.name, role: 'author' }
        ].to_json

        # Empty string means use defaults
        text_authorities = ''

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('copyrighted')
      end
    end

    context 'when authority has permission' do
      it 'returns copyrighted' do
        ingestible.default_authorities = [
          { seqno: 1, authority_id: permission_authority.id, authority_name: permission_authority.name, role: 'author' }
        ].to_json

        # Empty string means use defaults
        text_authorities = ''

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('copyrighted')
      end
    end

    context 'when text has explicit empty authorities array' do
      it 'returns copyrighted as there are no authorities to check' do
        ingestible.default_authorities = [
          { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
            role: 'author' }
        ].to_json

        text_authorities = '[]'

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('copyrighted')
      end
    end

    context 'when text overrides role with copyrighted authority' do
      it 'returns copyrighted' do
        ingestible.default_authorities = [
          { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
            role: 'author' }
        ].to_json

        text_authorities = [
          { seqno: 1, authority_id: copyrighted_authority.id, authority_name: copyrighted_authority.name,
            role: 'author' }
        ].to_json

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('copyrighted')
      end
    end

    context 'when collection authorities include copyrighted authority' do
      it 'returns copyrighted' do
        ingestible.collection_authorities = [
          { seqno: 1, authority_id: copyrighted_authority.id, authority_name: copyrighted_authority.name,
            role: 'editor' }
        ].to_json
        ingestible.default_authorities = [
          { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
            role: 'author' }
        ].to_json

        # Empty string means use defaults
        text_authorities = ''

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('copyrighted')
      end
    end

    context 'when no authorities with IDs present' do
      it 'returns copyrighted to be safe' do
        ingestible.default_authorities = [
          { seqno: 1, new_person: 'Unknown Author', role: 'author' }
        ].to_json

        # Empty string means use defaults
        text_authorities = ''

        expect(ingestible.calculate_copyright_status(text_authorities)).to eq('copyrighted')
      end
    end
  end

  describe '#merge_authorities_per_role' do
    it 'merges work and default authorities per role' do
      default_auths = [
        { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
          role: 'author' },
        { seqno: 2, authority_id: copyrighted_authority.id, authority_name: copyrighted_authority.name,
          role: 'translator' }
      ].to_json

      work_auths = [
        { seqno: 1, authority_id: orphan_authority.id, authority_name: orphan_authority.name, role: 'author' }
      ].to_json

      result = ingestible.send(:merge_authorities_per_role, work_auths, default_auths)

      # Should have the work's author (overriding default) and default translator
      expect(result.length).to eq(2)
      expect(result.map { |a| a['role'] }).to contain_exactly('author', 'translator')
      expect(result.find { |a| a['role'] == 'author' }['authority_id']).to eq(orphan_authority.id)
      expect(result.find { |a| a['role'] == 'translator' }['authority_id']).to eq(copyrighted_authority.id)
    end

    it 'returns empty array for explicit empty work authorities' do
      default_auths = [
        { seqno: 1, authority_id: public_domain_authority.id, authority_name: public_domain_authority.name,
          role: 'author' }
      ].to_json

      work_auths = '[]'

      result = ingestible.send(:merge_authorities_per_role, work_auths, default_auths)

      expect(result).to eq([])
    end
  end
end
