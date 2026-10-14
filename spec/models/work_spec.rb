require 'rails_helper'

describe Work do
  describe 'works_about' do
    let(:subject) { work.works_about.order(:id).to_a }
    let!(:work) { create(:work) }
    let!(:about_1)  {
      create(:work) do |w|
        create(:aboutness, work: w, aboutable: work)
      end
    }
    let!(:about_2)  {
      create(:work) do |w|
        create(:aboutness, work: w, aboutable: work)
      end
    }
    it { is_expected.to eq [about_1, about_2] }
  end

  describe 'genre' do
    it 'accepts visual_art' do
      expect(build(:work, genre: 'visual_art')).to be_valid
    end

    it 'rejects unknown genres' do
      expect(build(:work, genre: 'sculpture')).not_to be_valid
    end

    it 'orders visual_art last, right after lexicon (translations follow it in the UI)' do
      expect(Work::GENRES.last(2)).to eq(%w(lexicon visual_art))
    end
  end
    
end