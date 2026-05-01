# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ParsePersonWork do
  subject(:result) { described_class.call(list_item) }

  let(:list_item) { Nokogiri::HTML::DocumentFragment.parse("<li>#{line}</li>").at_css('li') }

  context 'when work string without comment is provided' do
    let(:line) { 'רוני צרצר לומד לעבוד (תל אביב : מ. ניומן, תשי"ג 1953)' }

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'רוני צרצר לומד לעבוד',
        publisher: 'מ. ניומן',
        publication_place: 'תל אביב',
        publication_date: 'תשי"ג 1953',
        comment: nil
      )
    end
  end

  context 'when work string with comment is provided' do
    # rubocop:disable Layout/LineLength
    let(:line) { 'וידויי ההרפתקן פליכס קרול : זכרונות, חלק ראשון / תומאס מאן (מרחביה : ספרית פועלים, 1956) <מהדורה מתוקנת יצאה לאור בתש״ם 1980>' }
    # rubocop:enable Layout/LineLength

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'וידויי ההרפתקן פליכס קרול : זכרונות, חלק ראשון / תומאס מאן',
        publisher: 'ספרית פועלים',
        publication_place: 'מרחביה',
        publication_date: '1956',
        comment: 'מהדורה מתוקנת יצאה לאור בתש״ם 1980'
      )
    end
  end

  context 'when hebrew year is specified' do
    let(:line) { 'באזקים : שירי מרדכי אבי־שאול (תל־אביב : כתובים, תרצ״ב) ' }

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'באזקים : שירי מרדכי אבי־שאול',
        publisher: 'כתובים',
        publication_place: 'תל־אביב',
        publication_date: 'תרצ״ב',
        comment: nil
      )
    end
  end

  context 'when line contains more than one colon and contains linebreaks' do
    let(:line) do
      <<~HTML
        קום קרא (חבל מודיעין : דביר : הקשרים – המכון לחקר הספרות והתרבות היהודית
          והישראלית, 2017)
      HTML
    end

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'קום קרא',
        publisher: 'דביר : הקשרים – המכון לחקר הספרות והתרבות היהודית והישראלית',
        publication_place: 'חבל מודיעין',
        publication_date: '2017',
        comment: nil
      )
    end
  end
end
