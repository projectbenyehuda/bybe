# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'backfill_authority_published_at rake task' do
  subject(:run_task) { task.invoke }

  before(:all) do
    Rake.application.rake_require 'tasks/backfill_authority_published_at'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['backfill_authority_published_at'] }

  before do
    task.reenable # allow the task to be run more than once across examples
    allow(AuthoritiesIndex).to receive(:import) # keep the reindex out of the specs
    allow($stdout).to receive(:puts) # the task is chatty by design
  end

  # Forces the NULL published_at this task exists to repair, regardless of whether the model is
  # already stamping it on create.
  def unstamped_authority(**attrs)
    create(:authority, status: :published, **attrs).tap { |a| a.update_column(:published_at, nil) }
  end

  context 'when the authority has published works' do
    let!(:authority) { unstamped_authority }
    let!(:first_work) { create(:manifestation, author: authority, created_at: 3.years.ago) }

    before { create(:manifestation, author: authority, created_at: 1.year.ago) }

    it 'stamps published_at from the earliest published work' do
      run_task
      expect(authority.reload.published_at).to be_within(1.second).of(first_work.created_at)
    end
  end

  context 'when the authority has no published works' do
    let!(:authority) { unstamped_authority(created_at: 2.years.ago) }

    it 'falls back to the authority created_at' do
      run_task
      expect(authority.reload.published_at).to be_within(1.second).of(authority.created_at)
    end
  end

  context 'when the authority has only unpublished works' do
    let!(:authority) { unstamped_authority(created_at: 2.years.ago) }

    before { create(:manifestation, author: authority, status: :unpublished, created_at: 3.years.ago) }

    it 'ignores them and falls back to the authority created_at' do
      run_task
      expect(authority.reload.published_at).to be_within(1.second).of(authority.created_at)
    end
  end

  it 'leaves an authority that already has a published_at untouched' do
    stamped = create(:authority, status: :published, published_at: 5.years.ago)
    create(:manifestation, author: stamped, created_at: 1.year.ago)
    expect { run_task }.not_to(change { stamped.reload.published_at })
  end

  it 'leaves unpublished authorities alone' do
    unpublished = create(:authority, status: :unpublished)
    unpublished.update_column(:published_at, nil)
    run_task
    expect(unpublished.reload.published_at).to be_nil
  end

  it 'reindexes the authorities index so the upload-date sort picks the dates up' do
    unstamped_authority
    run_task
    expect(AuthoritiesIndex).to have_received(:import)
  end

  it 'is idempotent' do
    authority = unstamped_authority
    create(:manifestation, author: authority, created_at: 3.years.ago)
    run_task
    stamped_at = authority.reload.published_at

    task.reenable
    task.invoke
    expect(authority.reload.published_at).to eq stamped_at
  end
end
