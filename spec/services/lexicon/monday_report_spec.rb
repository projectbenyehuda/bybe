# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::MondayReport do
  include WebMock::API

  let(:entry) { create(:lex_entry, :person, title: 'מוישה זוכמיר') }
  let(:current_url) { 'https://benyehuda.org/lex/verification/1234' }
  let(:captured_request) { {} }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_const('ENV', ENV.to_h.merge('MONDAY_BOARD_ID' => '5095697584', 'MONDAY_API_TOKEN' => 'test-token'))
  end

  def stub_monday_success(&block)
    stub_request(:post, 'https://api.monday.com/v2').to_return do |request|
      block&.call(request)
      {
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { create_item: { id: '123', name: 'מוישה זוכמיר', url: 'https://monday.com/item/123' } } }.to_json
      }
    end
  end

  def stub_monday_error(message = 'Invalid token')
    stub_request(:post, 'https://api.monday.com/v2')
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { errors: [{ message: message }] }.to_json
      )
  end

  describe '.call' do
    context 'when Monday env vars are not configured' do
      before { stub_const('ENV', ENV.to_h.merge('MONDAY_BOARD_ID' => nil, 'MONDAY_API_TOKEN' => nil)) }

      it 'returns an error without making an HTTP request' do
        # VCR/WebMock will raise if an unexpected HTTP call is made,
        # so the absence of an error confirms no request was attempted.
        result = described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(result[:success]).to be false
        expect(result[:error]).to include('not configured')
      end
    end

    context 'with a general report' do
      it 'returns success when Monday API succeeds' do
        stub_monday_success
        result = described_class.call(
          entry: entry,
          report_type: :general,
          current_url: current_url,
          description: 'נראה שחסר פה ככה וככה'
        )

        expect(result[:success]).to be true
      end

      it 'sends the entry title in the request body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_body).to include('מוישה זוכמיר')
      end

      it 'sends the general_name I18n text in the body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }
        expected = I18n.t('lexicon.verification.monday.general_name')

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_body).to include(expected)
      end

      it 'includes the description in the body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }
        description = 'נראה שחסר פה ככה וככה'

        described_class.call(entry: entry, report_type: :general, current_url: current_url, description: description)

        expect(captured_body).to include(description)
      end

      it 'includes the current_url in the body' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_body).to include('benyehuda.org')
      end

      it 'sends the Authorization header with the token' do
        captured_headers = nil
        stub_monday_success { |req| captured_headers = req.headers }

        described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(captured_headers['Authorization']).to eq('test-token')
      end

      it 'omits long_text column when description is blank' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(entry: entry, report_type: :general, current_url: current_url, description: nil)

        expect(captured_body).not_to include('long_text_mm2tzz8q')
      end
    end

    context 'with a missing_work report' do
      let(:publication) do
        create(:publication, title: 'שיר ערש', publisher_line: 'הוצאת דביר', pub_year: '1948')
      end

      it 'returns success when Monday API succeeds' do
        stub_monday_success
        result = described_class.call(
          entry: entry,
          report_type: :missing_work,
          current_url: current_url,
          publication: publication
        )

        expect(result[:success]).to be true
      end

      it 'includes the publication title in the missing_work_name text' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }
        expected = I18n.t('lexicon.verification.monday.missing_work_name', title: publication.title)

        described_class.call(
          entry: entry, report_type: :missing_work, current_url: current_url, publication: publication
        )

        expect(captured_body).to include(expected)
      end

      it 'includes the publisher and year in the long_text column' do
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(
          entry: entry, report_type: :missing_work, current_url: current_url, publication: publication
        )

        expect(captured_body).to include('long_text_mm2tzz8q')
        expect(JSON.parse(captured_body)['query']).to include('הוצאת דביר').and include('1948')
      end

      it 'falls back to the unknown label when publisher and year are blank' do
        publication.update!(publisher_line: nil, pub_year: nil)
        captured_body = nil
        stub_monday_success { |req| captured_body = req.body }

        described_class.call(
          entry: entry, report_type: :missing_work, current_url: current_url, publication: publication
        )

        expected = I18n.t('lexicon.verification.monday.missing_work_details',
                          publisher: I18n.t('unknown'), year: I18n.t('unknown'))
        expect(JSON.parse(captured_body)['query']).to include(expected)
      end
    end

    context 'with a fixed_broken_link report' do
      let(:person) { entry.lex_item }
      let(:old_link) { 'https://dead.example.com/page' }
      let(:new_link) { 'https://alive.example.com/page' }

      def report(record)
        described_class.call(
          entry: entry, report_type: :fixed_broken_link, current_url: current_url,
          record: record, old_link: old_link
        )
      end

      shared_examples 'a broken-link correction report' do
        it 'returns success when Monday API succeeds' do
          stub_monday_success

          expect(report(record)[:success]).to be true
        end

        it 'names the corrected record in the item name' do
          captured_body = nil
          stub_monday_success { |req| captured_body = req.body }

          report(record)

          expect(JSON.parse(captured_body)['query']).to include(expected_name)
        end

        it 'includes the old and new link values in the long_text column' do
          captured_body = nil
          stub_monday_success { |req| captured_body = req.body }

          report(record)

          query = JSON.parse(captured_body)['query']
          expect(query).to include('long_text_mm2tzz8q')
          expect(query).to include(old_link).and include(new_link)
        end

        it 'links back to the verification page' do
          captured_body = nil
          stub_monday_success { |req| captured_body = req.body }

          report(record)

          expect(JSON.parse(captured_body)['query']).to include(current_url)
        end
      end

      context 'when the corrected record is a citation' do
        let(:record) { create(:lex_citation, person: person, title: 'על מוישה זוכמיר', link: new_link) }
        let(:expected_name) do
          I18n.t('lexicon.verification.monday.fixed_broken_link_name',
                 subject: I18n.t('lexicon.verification.monday.fixed_broken_link_subject.citation',
                                 title: 'על מוישה זוכמיר'))
        end

        it_behaves_like 'a broken-link correction report'

        it 'reports a cleared link with the link_removed label rather than an empty value' do
          record.update!(link: nil)
          captured_body = nil
          stub_monday_success { |req| captured_body = req.body }
          expected = I18n.t('lexicon.verification.monday.fixed_broken_link_details',
                            old_link: old_link, new_link: I18n.t('lexicon.verification.monday.link_removed'))

          report(record)

          expect(JSON.parse(captured_body)['query']).to include(expected)
        end
      end

      context 'when the corrected record is a link' do
        let(:record) { create(:lex_link, item: person, description: 'אתר הזיכרון', url: new_link) }
        let(:expected_name) do
          I18n.t('lexicon.verification.monday.fixed_broken_link_name',
                 subject: I18n.t('lexicon.verification.monday.fixed_broken_link_subject.link',
                                 title: 'אתר הזיכרון'))
        end

        it_behaves_like 'a broken-link correction report'

        it 'falls back to the URL when the link has no description' do
          record.update!(description: nil)
          captured_body = nil
          stub_monday_success { |req| captured_body = req.body }
          expected = I18n.t('lexicon.verification.monday.fixed_broken_link_subject.link', title: new_link)

          report(record)

          expect(JSON.parse(captured_body)['query']).to include(expected)
        end
      end
    end

    context 'when Monday API returns an error response' do
      before { stub_monday_error('Invalid auth token') }

      it 'returns failure with the error message' do
        result = described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid auth token')
      end
    end

    context 'when the network call times out' do
      before { stub_request(:post, 'https://api.monday.com/v2').to_timeout }

      it 'returns failure without raising' do
        result = described_class.call(entry: entry, report_type: :general, current_url: current_url)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end
end
