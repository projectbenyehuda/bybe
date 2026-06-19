# frozen_string_literal: true

require 'rails_helper'

describe HtmlToMarkdown do
  subject(:result) { described_class.call(html) }

  context 'when html is nil' do
    let(:html) { nil }

    it { is_expected.to eq('') }
  end

  context 'when html is not nil' do
    let(:html) do
      <<~SNIPPET
        <h1>Header</h1>

        <p>Hello World</p>


      SNIPPET
    end

    it { is_expected.to eq("# Header\n\nHello World\n") }
  end

  context 'when html contains table' do
    let(:html) do
      <<~SNIPPET
        <h1>Header</h1>
        <table>
        <tr><td>Hello</td><td>World</td></tr>
        </table>
      SNIPPET
    end

    let(:expected_output) do
      <<~MARKDOWN
        # Header

        <table>
        <tbody>
        <tr>
        <td>Hello</td>
        <td>World</td>
        </tr>
        </tbody>
        </table>
      MARKDOWN
    end

    it 'renders table using raw html' do
      expect(result).to eq(expected_output)
    end
  end
end
