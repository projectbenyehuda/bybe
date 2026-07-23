# frozen_string_literal: true

require 'rails_helper'

describe ExpireCrowdsourcingTasksJob do
  subject(:call) do
    perform_enqueued_jobs do
      described_class.perform_later
    end
  end

  let(:user_1) { create(:user) }
  let(:person_1) { create(:authority).person }
  let(:person_2) { create(:authority).person }
  let(:user_2) { create(:user) }

  before do
    ListItem.create(
      item: person_1, user: user_1, listkey: CrowdController::LISTKEY_POPULATE_EDITION, updated_at: 121.minutes.ago
    )
    ListItem.create(
      item: person_2, user: user_2, listkey: CrowdController::LISTKEY_POPULATE_EDITION, updated_at: 119.minutes.ago
    )
  end

  it 'removes assigned crowdsourcing tasks updated more than two hours ago' do
    expect { call }.to change(ListItem, :count).by(-1)
    expect(ListItem.where(user: user_1)).to be_empty
    expect(ListItem.where(user: user_2)).to be_present
  end
end
