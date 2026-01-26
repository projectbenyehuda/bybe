# frozen_string_literal: true

require 'rails_helper'

describe '/files' do
  describe 'GET /files/:entry_type/:entry_id/:filename' do
    subject!(:call) { get "/files/#{record_type}/#{record_id}/#{filename}" }

    # requested attachment found by name
    let(:attachment) { record.images.detect { |att| att.filename.to_s == filename } }

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
      let(:record) do
        create(:manifestation).tap do |record|
          record.images.attach(
            io: StringIO.new('Test'),
            filename: 'file.txt',
            content_type: 'text/plain'
          )
          record.images.attach(
            io: StringIO.new('Double extension test'),
            filename: 'double.ext.txt',
            content_type: 'text/plain'
          )
          record.images.attach(
            io: StringIO.new('No extension test'),
            filename: 'no_extension',
            content_type: 'text/plain'
          )
          record.images.attach(
            io: Rails.root.join('spec/fixtures/files/test_image.jpg').open,
            filename: 'image.jpg',
            content_type: 'image/jpeg'
          )
        end
      end
      let(:record_id) { record.id }
      let(:record_type) { 'text' }

      context 'when non-image file is requested' do
        let(:filename) { 'file.txt' }

        it 'redirects to the file URL with attachment disposition' do
          expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
        end
      end

      context 'when image file is requested' do
        let(:filename) { 'image.jpg' }

        it 'redirects to the file URL with inline disposition' do
          expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'inline'))
        end
      end

      context 'when filename with double extension is requested' do
        let(:filename) { 'double.ext.txt' }

        it 'redirects to the file URL' do
          expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
        end
      end

      context 'when filename without extension is requested' do
        let(:filename) { 'no_extension' }

        it 'redirects to the file URL' do
          expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
        end
      end

      context 'when filename contains periods before the extension' do
        let(:filename) { 'photo.album.cover.jpg' }

        before do
          record.images.attach(
            io: StringIO.new('Test image'),
            filename: 'photo.album.cover.jpg',
            content_type: 'image/jpeg'
          )
        end

        it 'redirects to the file URL' do
          attachment = record.images.detect { |att| att.filename.to_s == filename }
          get "/files/#{record_type}/#{record_id}/#{filename}"
          expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'inline'))
        end
      end

      context 'when wrong entry_id is given' do
        let(:record_id) { record.id + 1 }
        let(:filename) { 'file.txt' }

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
      let(:record) do
        create(:static_page).tap do |record|
          record.images.attach(
            io: StringIO.new('Test'),
            filename: 'file.txt',
            content_type: 'text/plain'
          )
        end
      end
      let(:record_id) { record.id }
      let(:record_type) { 'static' }
      let(:filename) { 'file.txt' }

      it 'redirects to the file URL' do
        expect(response).to redirect_to(rails_blob_url(attachment.blob, disposition: 'attachment'))
      end
    end
  end
end
