# frozen_string_literal: true

describe HtmlToMarkdown do
  subject(:call) { HtmlToMarkdown.call(html) }

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
end