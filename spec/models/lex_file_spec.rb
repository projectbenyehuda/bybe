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

  describe '.log_error' do
    subject { file.error_message }

    let(:file) { create(:lex_file, error_message: error_message) }

    let(:error_message) { nil }

    context 'when error_message is empty' do
      before do
        file.log_error('Error message')
      end

      it { is_expected.to eq('Error message') }
    end

    context 'when error_message is not empty' do
      let(:error_message) { 'Old error message' }

      before do
        file.log_error('Error message')
      end

      it { is_expected.to eq("Old error message\nError message") }
    end

    context 'when method is called twice' do
      let(:error_message) { 'Old error message' }

      before do
        file.log_error('First')
        file.log_error('Second')
      end

      it { is_expected.to eq("Old error message\nFirst\nSecond") }
    end
  end
end
