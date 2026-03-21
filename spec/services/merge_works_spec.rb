# frozen_string_literal: true

require 'rails_helper'

describe MergeWorks do
  subject(:result) { described_class.call(older_work, newer_work) }

  let(:author) { create(:authority) }
  let(:older_work) { create(:work, title: 'Older Work', date: '1900', comment: nil, orig_lang: 'he', author: author) }
  let(:newer_work) do
    create(:work, title: 'Newer Work', date: '1920', comment: 'Newer comment', orig_lang: 'en', author: author)
  end
  let!(:expression_on_older) do
    create(:expression, work: older_work, title: 'Old Expression', intellectual_property: :public_domain)
  end
  let!(:expression_on_newer) do
    create(:expression, work: newer_work, title: 'New Expression', intellectual_property: :public_domain)
  end

  it 'succeeds' do
    expect(result[:success]).to be(true)
  end

  it 'keeps the older work' do
    expect(result[:kept_work_id]).to eq(older_work.id)
  end

  it 'moves the newer expression to the older work' do
    result
    expect(expression_on_newer.reload.work_id).to eq(older_work.id)
  end

  it 'keeps the older expression on the older work' do
    result
    expect(expression_on_older.reload.work_id).to eq(older_work.id)
  end

  it 'destroys the newer work' do
    result
    expect(Work.exists?(newer_work.id)).to be(false)
  end

  it 'copies empty fields from newer to older' do
    # older_work.comment is nil, newer_work.comment is 'Newer comment'
    result
    expect(older_work.reload.comment).to eq('Newer comment')
  end

  it 'does not overwrite non-empty fields on older work' do
    # older_work.orig_lang is 'he', newer_work.orig_lang is 'en'
    result
    expect(older_work.reload.orig_lang).to eq('he')
  end

  context 'when called with works in reverse order (newer first)' do
    subject(:result) { described_class.call(newer_work, older_work) }

    it 'still keeps the older work' do
      expect(result[:kept_work_id]).to eq(older_work.id)
    end

    it 'destroys the newer work' do
      result
      expect(Work.exists?(newer_work.id)).to be(false)
    end
  end

  context 'with aboutnesses on the newer work' do
    let!(:aboutness) { create(:aboutness, aboutable: newer_work) }

    it 'moves aboutnesses to the older work' do
      result
      expect(aboutness.reload.aboutable).to eq(older_work)
    end
  end

  context 'with taggings on the newer work' do
    let(:tag) { create(:tag) }
    let!(:tagging) { create(:tagging, tag: tag, taggable: newer_work, status: :approved) }

    it 'moves taggings to the older work' do
      result
      expect(tagging.reload.taggable).to eq(older_work)
    end

    context 'when the older work already has the same tag' do
      let!(:existing_tagging) { create(:tagging, tag: tag, taggable: older_work, status: :approved) }

      it 'destroys the duplicate tagging from the newer work' do
        result
        expect(Tagging.exists?(tagging.id)).to be(false)
      end

      it 'keeps the existing tagging on the older work' do
        result
        expect(Tagging.exists?(existing_tagging.id)).to be(true)
      end
    end
  end

  context 'when the works have different involved authorities' do
    let(:other_author) { create(:authority) }
    let(:newer_work) { create(:work, title: 'Different Author Work', date: '1920', author: other_author) }

    it 'fails with an error' do
      expect(result[:success]).to be(false)
      expect(result[:error]).to eq(I18n.t(:expressions_link_ia_mismatch))
    end

    it 'does not merge the works' do
      result
      expect(Work.exists?(newer_work.id)).to be(true)
    end
  end
end
