# frozen_string_literal: true

require 'rails_helper'

describe '/files' do
  describe 'GET /files/:entry_type/:entry_id/:filename' do
    subject(:call) { get "/files/#{record_type}/#{record_id}/#{filename}" }

    context 'when wrong entry_type is given' do
      let(:record_type) { 'foo' }
      let(:record_id) { 1 }
      let(:filename) { 'file.txt' }

      it 'Fails with Bad Request status' do
        expect(call).to eq(400)
        expect(response.body).to eq("Invalid record type: 'foo'")
      end
    end

    context 'when entry is a LexEntry' do
      let(:record_type) { 'lex' }
      let(:record) { create(:lex_entry) }
      let(:record_id) { record.id }

      before do
        record.attachments.attach(
          io: StringIO.new('First'),
          filename: 'file_1.txt',
          content_type: 'text/plain'
        )
        record.attachments.attach(
          io: StringIO.new('Second'),
          filename: 'file_2',
          content_type: 'text/plain'
        )
      end

      context 'when wrong entry_id is given' do
        let(:record_id) { record.id + 1 }
        let(:filename) { 'file_1.txt' }

        it 'fails with Not Found status' do
          expect(call).to eq(404)
          expect(response.body).to eq("Record not found: #{record_id}")
        end
      end

      context 'when wrong filename is given' do
        let(:filename) { 'missing.txt' }

        it 'fails with Not Found status' do
          expect(call).to eq(404)
          expect(response.body).to eq('File not found: missing.txt')
        end
      end

      context 'when correct file is requested' do
        let(:filename) { 'file_1.txt' }

        it 'redirects to the file URL' do
          attachment = record.attachments.detect { |att| att.filename.to_s == 'file_1.txt' }
          expect(call).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
        end
      end

      context 'when file without extension is requested' do
        let(:filename) { 'file_2' }

        it 'redirects to the file URL' do
          attachment = record.attachments.detect { |att| att.filename.to_s == 'file_2' }
          expect(call).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
        end
      end
    end

    context 'when record is a Manifestation' do
      let(:record) { create(:manifestation) }
      let(:record_id) { record.id }
      let(:record_type) { 'text' }
      let(:filename) { 'file.txt' }

      before do
        record.images.attach(
          io: StringIO.new('Test'),
          filename: 'file.txt',
          content_type: 'text/plain'
        )
      end

      it 'redirects to the file URL' do
        attachment = record.images.detect { |att| att.filename.to_s == 'file.txt' }
        expect(call).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
      end
    end
  end
end
