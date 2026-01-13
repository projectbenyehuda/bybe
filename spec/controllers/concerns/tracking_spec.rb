# frozen_string_literal: true

require 'rails_helper'

describe Tracking do
  let(:controller_class) do
    Class.new(ApplicationController) do
      include Tracking
    end
  end

  let(:controller) { controller_class.new }

  let(:regular_user_agent) { 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
  let(:spider_user_agent) { 'Googlebot/2.1 (+http://www.google.com/bot.html)' }
  let(:user_agent) { regular_user_agent } # defaults to regular browser

  let(:request_params) { {} }

  let(:request) do
    instance_double(
      ActionDispatch::TestRequest,
      user_agent: user_agent,
      filtered_parameters: request_params,
      parameters: request_params
    )
  end

  let(:base_user) { create(:base_user) }

  before do
    allow(controller).to receive_messages(
      request: request,
      base_user: base_user,
      ahoy: instance_double(Ahoy::Tracker, track: nil)
    )
  end

  describe '#spider?' do
    subject(:result) { controller.spider? }

    context 'when user_agent is a normal browser' do
      it { is_expected.to be false }
    end

    context 'when user_agent is a known spider' do
      let(:user_agent) { 'Googlebot/2.1 (+http://www.google.com/bot.html)' }

      it { is_expected.to be true }
    end
  end

  describe '#track_view' do
    subject(:call) { controller.track_view(manifestation) }

    let(:manifestation) do
      Chewy.strategy(:atomic) do
        create(:manifestation, impressions_count: impression_count)
      end
    end

    let(:manifestation_index) { ManifestationsIndex.find(manifestation.id) }

    let(:request_params) { { id: manifestation.id } }

    context 'when regular user agent' do
      let(:user_agent) { regular_user_agent }

      context 'when updated impressions_count is multiple of 10' do
        let(:impression_count) { 9 }

        it 'tracks view event and increments impressions_count in db and in ES' do
          expect { call }.to change { manifestation.reload.impressions_count }.by(1)
          expect(manifestation_index.impressions_count).to eq(impression_count + 1)
        end
      end

      context 'when updated impressions_count is not the multiple of 10' do
        let(:impression_count) { 1 }

        it 'tracks view event and increments impressions_count in db but not in ES' do
          expect { call }.to change { manifestation.reload.impressions_count }.by(1)
          expect(manifestation_index.impressions_count).to eq(impression_count)
        end
      end
    end

    context 'when user agent is known spider' do
      let(:impression_count) { 1 }
      let(:user_agent) { spider_user_agent }

      it 'does not track view event' do
        expect { call }.not_to(change { manifestation.reload.impressions_count })
        expect(manifestation_index.impressions_count).to eq(impression_count)
      end
    end
  end
end
