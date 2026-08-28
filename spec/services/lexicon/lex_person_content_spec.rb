# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::LexPersonContent do
  subject(:result) { described_class.call(lex_person) }

  let(:lex_person) do
    create(:lex_entry, :person).lex_item.tap do |lex_person|
      lex_person.deathdate = '1923'
      lex_person.birthdate = '1987'
      lex_person.citations = build_list(:lex_citation, 3)
      lex_person.works = build_list(:lex_person_work, 2)
      lex_person.save!
    end
  end

  it 'completes successfully' do
    expect(result).to be_present
  end

  context 'when the bio contains HTML' do
    let(:lex_person) do
      create(:lex_entry, :person).lex_item.tap do |person|
        person.birthdate = '1890'
        person.deathdate = '1955'
        person.bio = '<img src="/files/lex/1/photo.jpg" width="200" />' \
                     '<span>נולד בוורשה</span><br />ועלה לארץ &amp; התיישב בה' \
                     '<table><tbody><tr><td>ראשון</td><td>שני</td></tr></tbody></table>'
        person.save!
      end
    end

    it 'indexes the plain text of the bio, without markup' do
      expect(result).to include('נולד בוורשה')
      expect(result).not_to include('<img')
      expect(result).not_to include('photo.jpg')
      expect(result).not_to include('<span>')
    end

    it 'decodes HTML entities' do
      expect(result).to include('ועלה לארץ & התיישב בה')
    end

    it 'does not fuse words across block-level tag boundaries' do
      expect(result).to include('ראשון')
      expect(result).to include('שני')
      expect(result).not_to include('ראשוןשני')
      expect(result).not_to include('בוורשהועלה')
    end
  end

  context 'when the bio is blank' do
    let(:lex_person) do
      create(:lex_entry, :person).lex_item.tap do |person|
        person.birthdate = '1890'
        person.deathdate = '1955'
        person.bio = nil
        person.save!
      end
    end

    it 'completes successfully' do
      expect(result).to be_present
    end
  end

  context 'when a work is linked to a lex_publication' do
    let(:publication_entry) { create(:lex_entry, title: 'פרסום ייחודי', lex_item: create(:lex_publication)) }

    let(:lex_person) do
      create(:lex_entry, :person).lex_item.tap do |person|
        person.birthdate = '1950'
        person.deathdate = '2020'
        person.works = [build(:lex_person_work, title: 'original title', lex_publication: publication_entry.lex_item)]
        person.save!
      end
    end

    it 'uses the publication entry title in the indexed content' do
      expect(result).to include('פרסום ייחודי')
      expect(result).not_to include('original title')
    end
  end
end
