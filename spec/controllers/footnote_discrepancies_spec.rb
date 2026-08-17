# frozen_string_literal: true

require 'rails_helper'

# The scan itself is covered in spec/services/detect_footnote_discrepancies_spec.rb;
# here we only check that every markdown-editing screen actually runs it.
# One feature spread over four controllers, hence no single described class.
# rubocop:disable RSpec/DescribeClass
describe 'footnote discrepancy scanning on the markdown-editing screens' do
  # a reference with no body, plus a body with no reference
  let(:broken_markdown) { "טקסט עם הפניה[^1]\n\n[^2]: גוף ללא הפניה\n" }

  describe ManifestationController do
    include_context 'when editor logged in', :edit_catalog

    let!(:manifestation) { create(:manifestation, status: :published, markdown: broken_markdown) }

    it 'scans the markdown when editing' do
      get :edit, params: { id: manifestation.id }
      expect(assigns(:footnote_discrepancies)).to eq(
        orphan_references: [{ id: '1', lines: [1], section: nil }],
        orphan_bodies: [{ id: '2', lines: [3], section: nil }]
      )
    end

    it 'rescans the submitted markdown when previewing' do
      post :update, params: { id: manifestation.id, commit: I18n.t(:preview), markdown: "טקסט[^9]\n" }
      expect(assigns(:footnote_discrepancies)[:orphan_references]).to eq(
        [{ id: '9', lines: [1], section: nil }]
      )
    end
  end

  describe HtmlFileController do
    include_context 'when editor logged in', :edit_catalog

    let!(:html_file) { create(:html_file, markdown: markdown) }

    context 'with a single work' do
      let(:markdown) { broken_markdown }

      it 'scans the markdown' do
        get :edit_markdown, params: { id: html_file.id }
        expect(assigns(:footnote_discrepancies)).to eq(
          orphan_references: [{ id: '1', lines: [1], section: nil }],
          orphan_bodies: [{ id: '2', lines: [3], section: nil }]
        )
      end
    end

    context 'with works separated by &&&' do
      let(:markdown) { "&&& ראשונה\nטקסט[^1]\n\n&&& שנייה\n[^1]: גוף ההערה\n" }

      it 'does not match footnotes across the separator' do
        get :edit_markdown, params: { id: html_file.id }
        expect(assigns(:footnote_discrepancies)).to eq(
          orphan_references: [{ id: '1', lines: [2], section: 'ראשונה' }],
          orphan_bodies: [{ id: '1', lines: [5], section: 'שנייה' }]
        )
      end
    end
  end

  describe IngestiblesController do
    include_context 'when editor logged in', :edit_catalog

    let!(:ingestible) do
      create(:ingestible, :with_buffers, markdown: "&&& ראשונה\nטקסט[^1]\n\n&&& שנייה\n[^1]: גוף ההערה\n")
    end

    it 'scans the full markdown, per &&& section' do
      get :edit, params: { id: ingestible.id }
      expect(assigns(:footnote_discrepancies)).to eq(
        orphan_references: [{ id: '1', lines: [2], section: 'ראשונה' }],
        orphan_bodies: [{ id: '1', lines: [5], section: 'שנייה' }]
      )
    end

    it 'scans the text shown in the texts tab' do
      ingestible.texts[1] = IngestibleText.new('title' => 'כותרת', 'content' => broken_markdown)
      ingestible.save!
      get :edit, params: { id: ingestible.id, text_index: 1 }
      expect(assigns(:text_footnote_discrepancies)).to eq(
        orphan_references: [{ id: '1', lines: [1], section: nil }],
        orphan_bodies: [{ id: '2', lines: [3], section: nil }]
      )
    end
  end

  describe IngestibleTextsController do
    include_context 'when editor logged in', :edit_catalog

    let!(:ingestible) { create(:ingestible, :with_buffers) }

    it 'scans the edited text' do
      ingestible.texts[2] = IngestibleText.new('title' => 'כותרת', 'content' => broken_markdown)
      ingestible.save!
      get :edit, params: { ingestible_id: ingestible.id, id: 2 }, format: :js, xhr: true
      expect(assigns(:text_footnote_discrepancies)).to eq(
        orphan_references: [{ id: '1', lines: [1], section: nil }],
        orphan_bodies: [{ id: '2', lines: [3], section: nil }]
      )
    end
  end
end
# rubocop:enable RSpec/DescribeClass
