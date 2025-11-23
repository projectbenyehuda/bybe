# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, type: :model do
  describe 'validations' do
    it 'requires a name' do
      project = build(:project, name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to be_present
    end

    it 'is valid with all required attributes' do
      project = build(:project)
      expect(project).to be_valid
    end
  end

  describe '.active scope' do
    let!(:active_no_end_date) { create(:project, end_date: nil) }
    let!(:active_future_end) { create(:project, :future_end_date) }
    let!(:inactive_past_end) { create(:project, :inactive) }

    it 'includes projects with no end date' do
      expect(described_class.active).to include(active_no_end_date)
    end

    it 'includes projects with future end date' do
      expect(described_class.active).to include(active_future_end)
    end

    it 'excludes projects with past end date' do
      expect(described_class.active).not_to include(inactive_past_end)
    end

    it 'includes projects with end date equal to today' do
      today_project = create(:project, end_date: Date.current)
      expect(described_class.active).to include(today_project)
    end
  end
end
