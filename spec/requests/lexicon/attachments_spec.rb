# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/entries/<ENTRY_ID>/attachments' do
  before do
    login_as_lexicon_editor
  end

  let(:lex_entry) { create(:lex_entry, :person) }

  let!(:image) do
    lex_entry.attachments.attach(
      io: Rails.root.join(*%w(spec data lexicon attachments lorem_ipsum.png)).open,
      filename: 'image.png'
    ).last
  end

  let!(:pdf) do
    lex_entry.attachments.attach(
      io: Rails.root.join(*%w(spec data lexicon attachments lorem.pdf)).open,
      filename: 'lorem.pdf'
    ).last
  end

  let(:attached_filenames) do
    lex_entry.reload.attachments.map { |a| a.blob.filename.to_s }
  end

  describe 'GET /lexicon/entries/<ENTRY_ID>/attachments' do
    subject(:call) { get "/lex/entries/#{lex_entry.id}/attachments" }

    it 'renders attachment list' do
      expect(call).to eq(200)

      doc = Nokogiri::HTML(response.body)
      expect(doc.css('tr').count).to eq(3)  # one row in header and two rows for attachments
      expect(doc.css('img').count).to eq(1) # only image attachment should have a preview
    end
  end

  describe 'POST /lexicon/entries/<ENTRY_ID>/attachments' do
    subject(:call) { post "/lex/entries/#{lex_entry.id}/attachments", params: { attachment: file }, xhr: true }

    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec/data/lexicon/attachments/lorem_ipsum.png'),
        'image/png'
      )
    end

    it 'creates attachment' do
      expect { call }.to change { lex_entry.attachments.count }.by(1)
      expect(call).to eq(200)

      expect(attached_filenames).to eq(%w(image.png lorem.pdf lorem_ipsum.png))
    end

    context 'when file with the same name already exists' do
      let!(:image) do
        lex_entry.attachments.attach(
          io: Rails.root.join(*%w(spec data lexicon attachments lorem_ipsum.png)).open,
          filename: 'lorem_ipsum.png'
        ).last
      end

      it 'does not create attachment and shows alert message' do
        expect { call }.not_to(change { lex_entry.attachments.count })
        expect(call).to eq(200)
        expect(response.body).to include(
          "alert('#{I18n.t('lexicon.attachments.create.file_exists', filename: 'lorem_ipsum.png')}');"
        )
      end
    end
  end

  describe 'DELETE /lexicon/entries/<ENTRY_ID>/attachments/<ATTACHMENT_ID>' do
    subject(:call) { delete "/lex/entries/#{lex_entry.id}/attachments/#{pdf.blob_id}", xhr: true }

    it 'removes attachment' do
      expect { call }.to change { lex_entry.attachments.count }.by(-1)
      expect(call).to eq(200)

      expect(attached_filenames).to eq(%w(image.png))
    end
  end
end
