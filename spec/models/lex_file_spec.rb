# frozen_string_literal: true

require 'rails_helper'

describe LexFile do
  describe '.person_filename?' do
    subject { described_class.person_filename?(filename) }

    context 'when 5-digit filename is given' do
      let(:filename) { '12345.php' }

      it { is_expected.to be_truthy }
    end

    context 'when 4-digit filename is given' do
      let(:filename) { '1234.php' }

      it { is_expected.to be false }
    end

    context 'when 6-digit filename is given' do
      let(:filename) { '123456.php' }

      it { is_expected.to be false }
    end

    context 'when non-digit filename is given' do
      let(:filename) { '1234a.php' }

      it { is_expected.to be false }
    end
  end
end
