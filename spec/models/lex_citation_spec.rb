# frozen_string_literal: true

require 'rails_helper'

describe LexCitation do
  describe 'validations' do
    subject(:result) { citation.valid? }

    describe 'person_work association validation' do
      let(:person) { create(:lex_entry, :person).lex_item }
      let(:citation) { build(:lex_citation, person: person, person_work: person_work) }

      context 'when person_work is nil' do
        let(:person_work) { nil }

        it { is_expected.to be_truthy }
      end

      context 'when person_work belongs to same person' do
        let(:person_work) { create(:lex_person_work, person: person) }

        it { is_expected.to be_truthy }
      end

      context 'when person_work belongs to different person' do
        let(:other_person) { create(:lex_entry, :person).lex_item }
        let(:person_work) { create(:lex_person_work, person: other_person) }

        it 'fails with a validation message' do
          expect(result).to be false
          expect(citation.errors[:person_work]).to include(
            I18n.t('activerecord.errors.models.lex_citation.attributes.person_work.belongs_to_different_person')
          )
        end
      end
    end

    describe 'citation_group association validation' do
      let(:person) { create(:lex_entry, :person).lex_item }
      let(:group) { create(:lex_citation_group, person: person) }
      let(:citation) { build(:lex_citation, person: person, citation_group: group, person_work: person_work) }
      let(:person_work) { nil }

      it { is_expected.to be_truthy }

      context 'when the sub-heading belongs to a different person' do
        let(:group) { create(:lex_citation_group, person: create(:lex_entry, :person).lex_item) }

        it 'fails with a validation message' do
          expect(result).to be false
          expect(citation.errors[:citation_group]).to include(
            I18n.t('activerecord.errors.models.lex_citation.attributes.citation_group.belongs_to_different_person')
          )
        end
      end

      context 'when the citation is also about one of the person\'s works' do
        let(:person_work) { create(:lex_person_work, person: person) }

        it 'fails: a citation about a work is grouped by that work, not by a general sub-heading' do
          expect(result).to be false
          expect(citation.errors[:citation_group]).to include(
            I18n.t('activerecord.errors.models.lex_citation.attributes.citation_group.not_on_work_citation')
          )
        end
      end
    end
  end

  describe '#group_token' do
    let(:person) { create(:lex_entry, :person).lex_item }

    it 'is nil for a general citation under no heading' do
      expect(build(:lex_citation, person: person).group_token).to be_nil
    end

    it 'is the work title for a citation about a work' do
      work = create(:lex_person_work, person: person, title: 'מאמרים')
      expect(build(:lex_citation, person: person, person_work: work).group_token).to eq('מאמרים')
    end

    it 'is the legacy subject for a citation still carrying one' do
      expect(build(:lex_citation, person: person, subject: 'על "X"').group_token).to eq('על "X"')
    end

    # A person may well have a work titled 'מאמרים' as well as a general sub-heading of that name,
    # so the sub-heading is identified by id: keying on the title alone would merge the two groups.
    it 'is keyed by id for a general sub-heading, even one titled like a work' do
      work = create(:lex_person_work, person: person, title: 'מאמרים')
      group = create(:lex_citation_group, person: person, title: 'מאמרים')
      grouped = create(:lex_citation, person: person, citation_group: group)
      about_work = create(:lex_citation, person: person, person_work: work)

      expect(grouped.group_token).to eq("heading:#{group.id}")
      expect(grouped.group_token).not_to eq(about_work.group_token)
    end
  end

  # A Wayback Machine replacement for a dead anchored URL frequently repeats the anchor, which
  # makes the URL unparseable and so instantly "broken" again. See by-p6e.
  describe 'trimming a duplicated anchor from URL fields' do
    let(:citation) { build(:lex_citation, link: link, backup_url: backup_url) }
    let(:link) { 'https://web.archive.org/web/20200101/http://example.com/page#section#section' }
    let(:backup_url) { '/files/lex/7635/doc.pdf#p3#p3' }

    it 'keeps a single anchor in both link and backup_url' do
      citation.validate
      expect(citation.link).to eq 'https://web.archive.org/web/20200101/http://example.com/page#section'
      expect(citation.backup_url).to eq '/files/lex/7635/doc.pdf#p3'
    end

    context 'when the anchors are not duplicates' do
      let(:link) { 'http://example.com/page#section' }
      let(:backup_url) { nil }

      it 'leaves the values alone' do
        citation.validate
        expect(citation.link).to eq link
        expect(citation.backup_url).to be_nil
      end
    end
  end

  describe '#link_broken?' do
    subject { build(:lex_citation, link_checked_at: checked_at, link_http_status: status).link_broken? }

    context 'when never checked (checked_at nil)' do
      let(:checked_at) { nil }
      let(:status) { nil }

      it { is_expected.to be false }
    end

    context 'when checked and unreachable (status nil)' do
      let(:checked_at) { Time.current }
      let(:status) { nil }

      it { is_expected.to be true }
    end

    context 'when checked and healthy (status 200)' do
      let(:checked_at) { Time.current }
      let(:status) { 200 }

      it { is_expected.to be false }
    end

    context 'when checked and 404' do
      let(:checked_at) { Time.current }
      let(:status) { 404 }

      it { is_expected.to be true }
    end

    context 'when checked and 500' do
      let(:checked_at) { Time.current }
      let(:status) { 500 }

      it { is_expected.to be true }
    end

    context 'when link is a local file path (e.g. /files/lex/...)' do
      subject do
        build(:lex_citation, link: '/files/lex/7635/article.pdf',
                             link_checked_at: Time.current, link_http_status: nil).link_broken?
      end

      it { is_expected.to be false }
    end

    context 'when link is a local internal URL (e.g. /lex/entries/...)' do
      subject do
        build(:lex_citation, link: '/lex/entries/1234#no5',
                             link_checked_at: Time.current, link_http_status: nil).link_broken?
      end

      it { is_expected.to be false }
    end

    # A bot challenge (Cloudflare) tells us nothing about the link, so "we cannot tell" must not
    # be shown to editors as "broken". See by-9jz.
    context 'when the check hit a bot challenge (link_unverifiable)' do
      subject do
        build(:lex_citation, link_checked_at: Time.current, link_http_status: 403,
                             link_unverifiable: true).link_broken?
      end

      it { is_expected.to be false }
    end
  end
end
