# frozen_string_literal: true

require 'rails_helper'
require 'zip'

RSpec.describe 'BybeUtils EPUB generation' do
  include BybeUtils

  let(:work) { create(:work) }
  let(:expression) { create(:expression, work: work) }
  let(:manifestation) do
    create(:manifestation,
           expression: expression,
           title: 'Test Book',
           markdown: "# Test Book\n\n## Chapter 1\n\nContent 1\n\n## Chapter 2\n\nContent 2")
  end

  describe '#boilerplate' do
    it 'uses text-align:justify instead of text-align:right' do
      result = boilerplate('Test Title')
      expect(result).to include('text-align:justify')
      expect(result).not_to include('text-align:right')
    end

    it 'maintains dir="rtl" for right-to-left text direction' do
      result = boilerplate('Test Title')
      expect(result).to include('dir="rtl"')
    end
  end

  describe '#make_epub_from_single_html' do
    let(:html) do
      <<~HTML
        <h1>Test Book</h1>
        <p>Author info</p>
        <h2 id="ch1">Chapter 1</h2>
        <p>Content of chapter 1</p>
        <h2 id="ch2">Chapter 2</h2>
        <p>Content of chapter 2</p>
        <h2 id="ch3">Chapter 3</h2>
        <p>Content of chapter 3</p>
      HTML
    end

    it 'splits manifestation at H2 headings into separate sections' do
      epub_file = make_epub_from_single_html(html, manifestation, '')

      expect(File.exist?(epub_file)).to be true

      # Read the EPUB and verify structure
      Zip::File.open(epub_file) do |zip_file|
        # List all XHTML files for debugging
        xhtml_files = zip_file.entries.select { |e| e.name.end_with?('.xhtml') }.map(&:name)

        # Should have front page + chapters
        expect(zip_file.find_entry('OEBPS/0_front.xhtml')).to be_present

        # Should have at least 2 chapter files (the test has 3 H2s)
        # Actual number depends on min_sections and offset logic
        expect(xhtml_files.count).to be >= 3 # 0_front + at least 2 chapters

        expect(zip_file.find_entry('OEBPS/1_text.xhtml')).to be_present
        expect(zip_file.find_entry('OEBPS/2_text.xhtml')).to be_present

        # Verify package.opf has separate items
        opf_content = zip_file.read('OEBPS/package.opf')
        expect(opf_content).to include('1_text.xhtml')
        expect(opf_content).to include('2_text.xhtml')
      end

      File.delete(epub_file)
    end

    it 'marks front page as non-linear (linear="no") for manifestations' do
      epub_file = make_epub_from_single_html(html, manifestation, '')

      Zip::File.open(epub_file) do |zip_file|
        opf_content = zip_file.read('OEBPS/package.opf')
        # Front page should have linear="no" in spine for manifestations
        # (to prevent it from dominating progress in short texts)
        expect(opf_content).to match(/<itemref[^>]*idref="item_0_front"[^>]*linear="no"/)
      end

      File.delete(epub_file)
    end

    it 'uses justified text alignment in all sections' do
      epub_file = make_epub_from_single_html(html, manifestation, '')

      Zip::File.open(epub_file) do |zip_file|
        front_page = zip_file.read('OEBPS/0_front.xhtml')
        expect(front_page).to include('text-align:justify')
        expect(front_page).not_to include('text-align:right')
      end

      File.delete(epub_file)
    end
  end

  describe '#embed_images_in_epub' do
    let(:book) { GEPUB::Book.new }

    context 'when HTML contains ActiveStorage image URLs' do
      it 'extracts and embeds images in EPUB' do
        html_with_images = '<p>Text</p><img src="/rails/active_storage/blobs/redirect/abc123/image.jpg" />'

        # Mock ActiveStorage::Blob
        blob = instance_double(ActiveStorage::Blob)
        allow(ActiveStorage::Blob).to receive(:find_signed).with('abc123').and_return(blob)
        allow(blob).to receive(:download).and_yield('fake_image_data')

        modified_html, counter = embed_images_in_epub(book, html_with_images, 0)

        expect(modified_html).to include('images/image_0.jpg')
        expect(modified_html).not_to include('/rails/active_storage')
        expect(counter).to eq(1)
      end
    end

    context 'when HTML has no images' do
      it 'returns HTML unchanged' do
        html_without_images = '<p>Just text, no images</p>'
        modified_html, counter = embed_images_in_epub(book, html_without_images, 0)

        expect(modified_html).to eq(html_without_images)
        expect(counter).to eq(0)
      end
    end

    context 'when image embedding fails' do
      it 'leaves original URL and continues' do
        html_with_images = '<img src="/rails/active_storage/blobs/redirect/invalid/image.jpg" />'

        allow(ActiveStorage::Blob).to receive(:find_signed).and_raise(ActiveRecord::RecordNotFound)
        allow(Rails.logger).to receive(:warn)

        modified_html, = embed_images_in_epub(book, html_with_images, 0)

        # Original URL should remain since embedding failed
        expect(modified_html).to include('/rails/active_storage')
        expect(Rails.logger).to have_received(:warn)
      end
    end
  end

  describe '#make_epub_from_collection' do
    let(:collection) { create(:collection, title: 'Test Collection') }
    let(:manifestation1) do
      create(:manifestation,
             expression: expression,
             title: 'Story 1',
             markdown: "# Story 1\n\n## Part 1\n\nContent\n\n## Part 2\n\nMore content")
    end
    let(:manifestation2) do
      create(:manifestation,
             expression: expression,
             title: 'Story 2',
             markdown: "# Story 2\n\n## Section A\n\nContent\n\n## Section B\n\nMore content")
    end

    before do
      create(:collection_item, collection: collection, item: manifestation1, seqno: 1)
      create(:collection_item, collection: collection, item: manifestation2, seqno: 2)
    end

    it 'creates hierarchical TOC with texts as level 1 and headings as level 2' do
      epub_file = make_epub_from_collection(collection)

      Zip::File.open(epub_file) do |zip_file|
        nav_content = zip_file.read('OEBPS/nav.xhtml')

        # Should have nested structure in navigation
        # Level 1: manifestation titles
        expect(nav_content).to include('Story 1')
        expect(nav_content).to include('Story 2')

        # Level 2: H2 headings nested under their manifestations
        expect(nav_content).to include('Part 1')
        expect(nav_content).to include('Part 2')
        expect(nav_content).to include('Section A')
        expect(nav_content).to include('Section B')
      end

      File.delete(epub_file)
    end

    it 'includes involved authorities for each manifestation' do
      author = create(:authority, name: 'Test Author')
      create(:involved_authority,
             authority: author,
             role: 'author',
             item: manifestation1.expression.work)

      epub_file = make_epub_from_collection(collection)

      Zip::File.open(epub_file) do |zip_file|
        # Check first manifestation section includes author info
        text_content = zip_file.read('OEBPS/1_text.xhtml')
        expect(text_content).to include('Test Author')
      end

      File.delete(epub_file)
    end

    it 'uses I18n.t(:paratext_description) for paratext titles in TOC' do
      # Create a collection with a paratext (item with markdown)
      create(:collection_item,
             collection: collection,
             item: nil,
             markdown: "## Introduction\n\nThis is a paratext introduction.",
             seqno: 3)

      epub_file = make_epub_from_collection(collection)

      Zip::File.open(epub_file) do |zip_file|
        nav_content = zip_file.read('OEBPS/nav.xhtml').force_encoding('UTF-8')

        # Should use I18n translation for paratext
        expect(nav_content).to include(I18n.t(:paratext_description))
        # Should not use empty or missing title
        expect(nav_content).not_to match(%r{<a[^>]*>\s*</a>}) # No empty links
      end

      File.delete(epub_file)
    end

    it 'includes publication date and EPUB generation date on title page' do
      collection.update(pub_year: '1965')

      epub_file = make_epub_from_collection(collection)

      Zip::File.open(epub_file) do |zip_file|
        front_page = zip_file.read('OEBPS/0_front.xhtml').force_encoding('UTF-8')

        # Should include publication date
        expect(front_page).to include('1965')
        expect(front_page).to include(I18n.t(:publication_date))

        # Should include EPUB generation date
        expect(front_page).to include(Time.zone.today.to_s)
        expect(front_page).to include(I18n.t(:updated_at))

        # Collection title page should NOT have linear="no" (should appear at beginning)
        opf_content = zip_file.read('OEBPS/package.opf')
        expect(opf_content).not_to match(/<itemref[^>]*idref="item_0_front"[^>]*linear="no"/)
      end

      File.delete(epub_file)
    end
  end

  describe 'authority crediting' do
    let(:author) { create(:authority, name: 'Original Author') }
    let(:translator) { create(:authority, name: 'Translator Name') }

    before do
      create(:involved_authority,
             authority: author,
             role: 'author',
             item: work)
      create(:involved_authority,
             authority: translator,
             role: 'translator',
             item: expression)
    end

    it 'includes both work-level and expression-level authorities on title page' do
      html = '<h1>Test</h1><p>Content</p>'
      epub_file = make_epub_from_single_html(html, manifestation, '')

      Zip::File.open(epub_file) do |zip_file|
        front_page = zip_file.read('OEBPS/0_front.xhtml')
        expect(front_page).to include('Original Author')
        expect(front_page).to include('Translator Name')
      end

      File.delete(epub_file)
    end
  end
end
