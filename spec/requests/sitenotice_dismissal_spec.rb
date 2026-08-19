# frozen_string_literal: true

require 'rails_helper'

# Regression: dismissal used to set a single boolean in the session, which suppressed
# every future sitenotice for the lifetime of the session (60 days).
RSpec.describe 'Sitenotice dismissal', type: :request do
  # any page rendering the standard layout will do; the login page is the cheapest one
  let(:page_path) { session_login_path }
  let!(:first_notice) { create(:sitenotice, body: 'First notice') }

  it 'stops showing a dismissed notice, but still shows notices created afterwards' do
    get page_path
    expect(response.body).to include('First notice')

    get session_dismiss_sitenotice_path
    expect(response).to have_http_status(:ok)
    expect(session[:dismissed_sitenotices]).to eq([first_notice.id])

    get page_path
    expect(response.body).not_to include('First notice')

    create(:sitenotice, body: 'Second notice')
    get page_path
    expect(response.body).to include('Second notice')
  end

  it 'keeps earlier dismissals when a later notice is dismissed' do
    get session_dismiss_sitenotice_path
    second_notice = create(:sitenotice, body: 'Second notice')
    get session_dismiss_sitenotice_path

    expect(session[:dismissed_sitenotices]).to contain_exactly(first_notice.id, second_notice.id)

    get page_path
    expect(response.body).not_to include('First notice')
    expect(response.body).not_to include('Second notice')
  end

  it 'builds the notice list only once per request, though the layout asks for it twice' do
    allow(Sitenotice).to receive(:in_effect_notices).and_call_original

    get page_path

    expect(response.body).to include('First notice')
    expect(Sitenotice).to have_received(:in_effect_notices).once
  end

  it 'ignores notices that are not in effect' do
    create(:sitenotice, body: 'Expired notice', fromdate: 1.month.ago, todate: 1.week.ago)
    create(:sitenotice, body: 'Disabled notice', status: :disabled)

    get page_path
    expect(response.body).to include('First notice')
    expect(response.body).not_to include('Expired notice')
    expect(response.body).not_to include('Disabled notice')

    get session_dismiss_sitenotice_path
    expect(session[:dismissed_sitenotices]).to eq([first_notice.id])
  end
end
