# frozen_string_literal: true

require 'rails_helper'

# Every filter option rendered by shared/filters/_checkboxes must have its label
# wired to its own checkbox via `for`, so that clicking the label text toggles
# the box and screen readers announce the two as one control. That only holds if
# the generated ids ("#{group_name}_#{value}") are unique on the page --
# shared/filters/_languages in particular renders the partial twice under the
# same group_name, relying on the two value sets being disjoint.
RSpec.describe 'Filter checkbox labels', type: :request do
  around do |example|
    I18n.with_locale(:he) { example.run }
  end

  # /works and /authors build their facet counts from Elasticsearch aggregations
  # and blow up on an empty index, so give both indices something to aggregate.
  let!(:work) { create(:manifestation, author: create(:authority, gender: 'female')) }

  before do
    import_and_await(ManifestationsIndex, [work])
    import_and_await(AuthoritiesIndex, Authority.all.to_a)
  end

  after do
    Chewy.massacre
  end

  def filter_panel
    Nokogiri::HTML(response.body).at_css('#filters_panel')
  end

  shared_examples 'labelled filter checkboxes' do |page_name, path_helper|
    before { get send(path_helper) }

    it "gives every filter checkbox on #{page_name} a label bound to it" do
      rows = filter_panel.css('.filter-checkbox')
      expect(rows).not_to be_empty

      unbound = rows.reject do |row|
        checkbox = row.at_css('input[type=checkbox]')
        label = row.at_css('label')
        checkbox && label && checkbox['id'].present? && label['for'] == checkbox['id']
      end

      expect(unbound.map(&:text).map(&:squish)).to eq([])
    end

    it "keeps the generated checkbox ids unique across #{page_name}" do
      ids = Nokogiri::HTML(response.body).css('input[type=checkbox][id]').pluck('id')

      expect(ids).to eq(ids.uniq)
    end
  end

  it_behaves_like 'labelled filter checkboxes', 'the works browse page', :works_path
  it_behaves_like 'labelled filter checkboxes', 'the authors browse page', :authors_path
  it_behaves_like 'labelled filter checkboxes', 'the collections browse page', :collections_path
  it_behaves_like 'labelled filter checkboxes', 'the lexicon entries list', :lexicon_entries_list_path
end
