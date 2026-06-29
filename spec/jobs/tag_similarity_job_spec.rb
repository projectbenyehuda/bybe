# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TagSimilarityJob, type: :job do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'reports similar tags' do
    user = create(:user)
    similar_tag = create(:tag, name: 'test1', creator: user, status: 'approved')
    tag = create(:tag, name: 'test2', creator: user, status: 'pending')

    described_class.perform_now(tag.id) # find similar tags

    expect(ListItem.where(listkey: 'tag_similarity', item: tag).count).to eq 1
    expect(ListItem.where(listkey: 'tag_similarity', item: tag).first.extra).to eq "80%:#{similar_tag.id}"
  end

  it 'enqueues a job' do
    user = create(:user)
    create(:tag, name: 'test1', creator: user, status: 'approved')
    tag = create(:tag, name: 'test2', creator: user, status: 'pending')

    expect { described_class.perform_later(tag.id) }.to have_enqueued_job(described_class).with(tag.id)
  end

  it 'does not report dissimilar tags' do
    user = create(:user)
    create(:tag, name: 'test1', creator: user, status: 'approved')
    dissimilar_tag = create(:tag, name: 'absolutely-different-tag', creator: user, status: 'pending')

    described_class.perform_now(dissimilar_tag.id) # find similar tags

    expect(ListItem.where(listkey: 'tag_similarity', item: dissimilar_tag).count).to eq 0
  end
end
