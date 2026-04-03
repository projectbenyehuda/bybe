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
        call
        expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
      end

      context 'when wrong entry_id is given' do
        let(:record_id) { record.id + 1 }

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
    end

    context 'when record is a StaticPage' do
      let(:record) { create(:static_page) }
      let(:record_id) { record.id }
      let(:record_type) { 'static' }
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
        call
        expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
      end
    end
  end
end
