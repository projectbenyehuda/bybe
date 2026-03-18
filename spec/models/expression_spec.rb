require 'rails_helper'

describe Expression do
  describe '#normalized_first_publication_date' do
    it 'is auto-computed from first_publication_date on save' do
      expression = create(:expression, first_publication_date: '1910')
      expect(expression.normalized_first_publication_date).to be_present
    end

    it 'remains nil when first_publication_date is blank' do
      expression = create(:expression, first_publication_date: nil)
      expect(expression.normalized_first_publication_date).to be_nil
    end

    it 'updates when first_publication_date changes' do
      expression = create(:expression, first_publication_date: nil)
      expression.update!(first_publication_date: '1920')
      expect(expression.normalized_first_publication_date).to be_present
    end
  end

  describe '.cached_work_counts_by_periods' do
    let(:subject) { Expression.cached_work_count_by_periods }

    before do
      create(:manifestation, status: :unpublished, period: :ancient)
      create(:manifestation, period: :ancient)
      create(:manifestation, period: :medieval)
      create(:manifestation, period: :medieval)
    end

    it 'does not counts unpublished works' do
      expect(subject.size).to eq 2
      expect(subject['ancient']).to eq 1
      expect(subject['medieval']).to eq 2
    end
  end
end