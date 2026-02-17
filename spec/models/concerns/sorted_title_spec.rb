# frozen_string_literal: true

require 'rails_helper'

describe SortedTitle do
  before do
    stub_const(
      'Model',
      Class.new do
        include ActiveModel::Validations
        include ActiveModel::Validations::Callbacks
        include ActiveModel::Dirty
        include SortedTitle

        attr_accessor :title, :sort_title

        define_attribute_methods :title, :sort_title

        def initialize(title)
          @title = title
        end
      end
    )
  end

  let(:model) { Model.new(title) }

  describe '.strip_whitespaces_from_title!' do
    before do
      model.strip_whitespaces_from_title!
    end

    context 'when title contains leading and trailing whitespaces' do
      let(:title) { '  Some Title  ' }

      it { expect(model.title).to eq('Some Title') }
    end
  end

  describe '.update_sort_title!' do
    before do
      model.strip_whitespaces_from_title!
      model.update_sort_title!
    end

    context 'when title contains leading and trailing whitespaces' do
      let(:title) { '  התרבותית  ' }

      it 'removes leading and trailing whitespaces' do
        expect(model.sort_title).to eq('התרבותית')
      end
    end

    context 'when title starts with a number and dot prefix' do
      let(:title) { '14. התרבותית' }

      it 'removes numeric prefix with dot and whitespace' do
        expect(model.sort_title).to eq('התרבותית')
      end
    end

    context 'when title starts from digits (without dot)' do
      let(:title) { '1st Title' }

      it 'matches from title' do
        expect(model.sort_title).to eq('1st Title')
      end
    end

    context 'when title starts with non-digit and non-hebrew character' do
      let(:title) { 'Lord of the Rings' }

      it 'adds special prefix to position it after all hebrew titles' do
        expect(model.sort_title).to eq('תתתת_Lord of the Rings')
      end
    end
  end

  describe 'before validation hook' do
    let(:title) { ' 1. Some Title  ' }

    before do
      allow(model).to receive(:strip_whitespaces_from_title!).and_call_original
      allow(model).to receive(:update_sort_title!).and_call_original
    end

    it 'calls strip_whitespaces_from_title! and update_sort_title! in before_validation hook' do
      model.valid?
      expect(model).to have_received(:strip_whitespaces_from_title!).once
      expect(model).to have_received(:update_sort_title!).once

      expect(model.title).to eq('1. Some Title')
      expect(model.sort_title).to eq('תתתת_Some Title')
    end

    context 'when title was changed but sort_title was not changed' do
      before do
        model.title = ' New Value '
      end

      it 'generates new sort_title value' do
        model.valid?
        expect(model).to have_received(:strip_whitespaces_from_title!).once
        expect(model).to have_received(:update_sort_title!).once
        expect(model.title).to eq('New Value')
        expect(model.sort_title).to eq('תתתת_New Value')
      end
    end

    context 'when both title and sort_title was changed' do
      before do
        model.title = ' New Value '
        model.sort_title = ' New Sort Title '
      end

      it 'does not generates new sort_title value' do
        model.valid?
        expect(model).to have_received(:strip_whitespaces_from_title!).once
        expect(model).not_to have_received(:update_sort_title!)
        expect(model.title).to eq('New Value')
        expect(model.sort_title).to eq(' New Sort Title ')
      end
    end

    context 'when title was changed and sort_title changed to blank value' do
      before do
        model.title = ' New Value '
        model.sort_title = ' '
      end

      it 'generates new sort_title value' do
        model.valid?
        expect(model).to have_received(:strip_whitespaces_from_title!).once
        expect(model).to have_received(:update_sort_title!).once
        expect(model.title).to eq('New Value')
        expect(model.sort_title).to eq('תתתת_New Value')
      end
    end
  end
end
