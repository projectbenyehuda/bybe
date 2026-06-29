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
    u = create(:user)
    t = Tag.new(name: 'test1', creator: u, status: 'approved')
    t.save # a TagName is created as well
    t2 = Tag.new(name: 'test2', creator: u, status: 'pending')
    t2.save

    described_class.perform_now(t2.id) # find similar tags

    expect(ListItem.where(listkey: 'tag_similarity', item: t2).count).to eq 1
    expect(ListItem.where(listkey: 'tag_similarity', item: t2).first.extra).to eq "80%:#{t.id}"
  end

  it 'enqueues a job' do
    u = create(:user)
    create(:tag, name: 'test1', creator: u, status: 'approved')
    t2 = create(:tag, name: 'test2', creator: u, status: 'pending')

    expect { described_class.perform_later(t2.id) }.to have_enqueued_job(described_class).with(t2.id)
  end

  it 'does not report dissimilar tags' do
    u = create(:user)
    create(:tag, name: 'test1', creator: u, status: 'approved')
    t2 = create(:tag, name: 'absolutely-different-tag', creator: u, status: 'pending')

    described_class.perform_now(t2.id) # find similar tags

    expect(ListItem.where(listkey: 'tag_similarity', item: t2).count).to eq 0
  end
end
