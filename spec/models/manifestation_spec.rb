# frozen_string_literal: true

require 'rails_helper'

describe Manifestation do
  describe '.safe_filename' do
    let(:manifestation) { create(:manifestation) }
    let(:subject) { manifestation.safe_filename }

    it { is_expected.to eq manifestation.id.to_s }
  end

  describe '.genre(genre)' do
    before do
      create_list(:manifestation, 3, genre: :article)
      create_list(:manifestation, 2, genre: :article, status: :unpublished)
      create_list(:manifestation, 4, genre: :prose)
    end

    it 'takes in account unpublished manifestations as well' do
      expect(described_class.genre(:article).count).to eq 5
    end
  end

  describe '.cached_work_counts_by_genre' do
    subject { described_class.cached_work_counts_by_genre }

    before do
      create_list(:manifestation, 3, genre: :article)
      create_list(:manifestation, 4, genre: :prose)
      create_list(:manifestation, 5, genre: :fables)
    end

    let(:expected_result) do
      {
        'article' => 3,
        'drama' => 0,
        'fables' => 5,
        'letters' => 0,
        'lexicon' => 0,
        'memoir' => 0,
        'poetry' => 0,
        'prose' => 4,
        'reference' => 0
      }
    end

    it { is_expected.to eq expected_result }

    context 'when unpublished works exists' do
      before do
        create_list(:manifestation, 2, genre: :article, status: :unpublished)
        create_list(:manifestation, 2, genre: :lexicon, status: :unpublished)
        create_list(:manifestation, 2, genre: :prose, status: :unpublished)
      end

      it 'does not takes them in account' do
        expect(subject).to eq expected_result
      end
    end
  end

  describe '.manual_delete' do
    subject(:manual_delete) { manifestation.manual_delete }

    let!(:manifestation) { create(:manifestation, orig_lang: 'de') }

    it 'removes record with all dependent subrecords' do
      expect { manual_delete }.to change(described_class, :count).by(-1)
                                                                 .and change(Expression, :count).by(-1)
                                                                 .and change(Work, :count).by(-1)
                                                                 .and change(InvolvedAuthority, :count).by(-2)
                                                                 .and not_change(Person, :count)
    end
  end

  describe '.authors_string' do
    subject { manifestation.authors_string }
    context 'when authors present' do
      let(:author_1) { create(:authority, name: 'Alpha') }
      let(:author_2) { create(:authority, name: 'Beta') }
      let(:manifestation) do
        create(:manifestation, author: author_1).tap do |manifestation|
          manifestation.expression.work.involved_authorities.create!(role: :author, authority: author_2)
        end
      end

      it { is_expected.to eq 'Alpha, Beta' }
    end

    context 'when no authors present' do
      let(:manifestation) { create(:manifestation) }

      before do
        manifestation.expression.work.involved_authorities.delete_all
        manifestation.reload
      end

      it { is_expected.to eq I18n.t(:nil) }
    end
  end

  describe '.translators_string' do
    subject { manifestation.translators_string }
    context 'when translators present' do
      let(:translator_1) { create(:authority, name: 'Alpha') }
      let(:translator_2) { create(:authority, name: 'Beta') }
      let(:manifestation) do
        create(:manifestation, orig_lang: 'de', translator: translator_1).tap do |manifestation|
          manifestation.expression.involved_authorities.create!(role: :translator, authority: translator_2)
        end
      end

      it { is_expected.to eq 'Alpha, Beta' }
    end

    context 'when no translators present' do
      let(:manifestation) { create(:manifestation, orig_lang: 'de') }

      before do
        manifestation.expression.involved_authorities.delete_all
        manifestation.reload
      end

      it { is_expected.to eq I18n.t(:nil) }
    end
  end

  describe '.author_string' do
    subject { manifestation.author_string }

    let(:author_1) { create(:authority, name: 'Alpha') }
    let(:author_2) { create(:authority, name: 'Beta') }

    before do
      create(:involved_authority, item: manifestation.expression.work, role: :author, authority: author_2)
      manifestation.reload
    end

    context 'when work is not a translation' do
      let(:manifestation) { create(:manifestation, orig_lang: 'he', author: author_1) }

      context 'when authors are present' do
        it { is_expected.to eq 'Alpha, Beta' }
      end

      context 'when no authors present' do
        before do
          manifestation.expression.work.involved_authorities.delete_all
          manifestation.reload
        end

        it { is_expected.to eq I18n.t(:nil) }
      end
    end

    context 'when work is a translation' do
      let(:translator_1) { create(:authority, name: 'Gamma') }
      let(:translator_2) { create(:authority, name: 'Delta') }

      let(:manifestation) do
        create(:manifestation, orig_lang: 'de', author: author_1, translator: translator_1).tap do |manifestation|
          manifestation.expression.involved_authorities.create!(role: :translator, authority: translator_2)
        end
      end

      context 'when both authors and transaltors are present' do
        it { is_expected.to eq 'Alpha, Beta / Gamma, Delta' }
      end

      context 'when no authors present' do
        before do
          manifestation.expression.work.involved_authorities.delete_all
          manifestation.reload
        end

        it { is_expected.to eq I18n.t(:nil) }
      end

      context 'when no translators present' do
        before do
          manifestation.expression.involved_authorities.delete_all
          manifestation.reload
        end

        it { is_expected.to eq 'Alpha, Beta / ' + I18n.t(:unknown) }
      end
    end
  end

  describe '.title_and_authors_html' do
    subject(:string) { manifestation.title_and_authors_html }

    context 'when work is not a translation' do
      let(:manifestation) { create(:manifestation, orig_lang: :he) }

      it 'does not include info about translation' do
        expect(string.include?(I18n.t(:translated_from))).to be false
      end
    end

    context 'when work is a translation' do
      let(:manifestation) { create(:manifestation, orig_lang: :de) }

      it 'includes info about translation' do
        expect(string.include?(I18n.t(:translated_from))).to be_truthy
      end
    end
  end

  describe '.approved_tags' do
    subject { manifestation.approved_tags }

    let(:manifestation) { create(:manifestation) }
    let(:approved_tag) { create(:tag, status: :approved) }
    let(:pending_tag) { create(:tag, status: :pending) }

    let!(:approved_approved_tagging) { create(:tagging, tag: approved_tag, taggable: manifestation, status: :approved) }
    let!(:approved_pending_tagging) { create(:tagging, tag: pending_tag, taggable: manifestation, status: :approved) }
    let!(:pending_approved_tagging) { create(:tagging, tag: approved_tag, taggable: manifestation, status: :pending) }

    it { is_expected.to contain_exactly(approved_tag) }
  end

  describe '.to_html' do
    subject { manifestation.to_html }
    let(:manifestation) { create(:manifestation, markdown: "## Test", status: status) }

    context 'when published' do
      let(:status) { :published }

      it { is_expected.to eq "<h2 id=\"test\">Test</h2>\n" }
    end

    context 'when unpublished' do
      let(:status) { :unpublished }

      it { is_expected.to eq I18n.t(:not_public_yet) }
    end
  end

  describe '#fresh_downloadable_for' do
    let(:manifestation) { create(:manifestation) }

    context 'when downloadable has attached file' do
      let!(:downloadable) { create(:downloadable, :with_file, object: manifestation, doctype: :pdf) }

      it 'returns the downloadable' do
        expect(manifestation.fresh_downloadable_for('pdf')).to eq downloadable
      end
    end

    context 'when downloadable exists but has no attached file' do
      let!(:downloadable) { create(:downloadable, :without_file, object: manifestation, doctype: :pdf) }

      it 'returns nil' do
        expect(manifestation.fresh_downloadable_for('pdf')).to be_nil
      end
    end

    context 'when no downloadable exists' do
      it 'returns nil' do
        expect(manifestation.fresh_downloadable_for('pdf')).to be_nil
      end
    end
  end

  describe '#recalc_responsibility_statement' do
    let(:author) { create(:authority, name: 'Test Author') }
    let(:translator) { create(:authority, name: 'Test Translator') }
    let(:manifestation) { create(:manifestation, orig_lang: 'de', author: author, translator: translator) }

    it 'updates responsibility_statement to match author_string' do
      manifestation.recalc_responsibility_statement
      expect(manifestation.responsibility_statement).to eq(manifestation.author_string!)
    end

    it 'does not save the record' do
      expect { manifestation.recalc_responsibility_statement }.not_to change(manifestation, :updated_at)
    end
  end

  describe '#recalc_responsibility_statement!' do
    let(:author) { create(:authority, name: 'Test Author') }
    let(:translator) { create(:authority, name: 'Test Translator') }
    let(:manifestation) { create(:manifestation, orig_lang: 'de', author: author, translator: translator) }

    it 'updates and saves responsibility_statement to match author_string' do
      manifestation.recalc_responsibility_statement!
      manifestation.reload
      expect(manifestation.responsibility_statement).to eq(manifestation.author_string!)
    end
  end
end
