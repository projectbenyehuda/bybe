# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'tempfile'

RSpec.describe 'export_catalog rake task' do # rubocop:disable RSpec/DescribeClass
  before(:all) do
    Rake.application.rake_require 'tasks/export_catalog'
    Rake::Task.define_task(:environment)
  end

  let(:output_tempfile) { Tempfile.new(['catalog_export', '.json']) }
  let(:output_file) { output_tempfile.path }

  let(:task) { Rake::Task['export_catalog'] }

  before do
    task.reenable
    ENV['EXPORT_CATALOG_OUTPUT'] = output_file
    allow(ARGV).to receive(:include?).with('--all').and_return(false)
  end

  after do
    ENV.delete('EXPORT_CATALOG_OUTPUT')
    ENV.delete('EXPORT_CATALOG_LIMIT')
    output_tempfile.close
    output_tempfile.unlink
  end

  def parsed_output
    JSON.parse(File.read(output_file))
  end

  context 'with a qualifying volume collection' do
    let!(:author) { create(:authority) }
    let!(:manifestation) do
      create(:manifestation, author: author, status: :published, orig_lang: 'en')
    end
    let!(:collection) do
      create(:collection,
             collection_type: :volume,
             title: 'Test Volume',
             subtitle: 'A subtitle',
             publisher_line: 'Publisher Co.',
             alternate_titles: 'Alt Title One; Alt Title Two',
             manifestations: [manifestation])
    end

    it 'writes valid JSON with the expected top-level structure' do
      task.invoke
      data = parsed_output
      expect(data).to include('mode', 'collections', 'count')
    end

    it 'includes the collection with required fields' do
      task.invoke
      c = parsed_output['collections'].first
      expect(c).to include('type' => 'collection', 'id' => collection.id, 'title' => 'Test Volume')
      expect(c['url']).to match(%r{/collections/#{collection.id}})
    end

    it 'includes subtitle and publisher_line when present' do
      task.invoke
      c = parsed_output['collections'].first
      expect(c['subtitle']).to eq('A subtitle')
      expect(c['publisher_line']).to eq('Publisher Co.')
    end

    it 'splits alternate_titles on semicolon regardless of spacing' do
      collection.update!(alternate_titles: 'One;Two ; Three')
      task.invoke
      c = parsed_output['collections'].first
      expect(c['alternate_titles']).to eq(%w(One Two Three))
    end

    it 'serializes manifestation contents with id and url' do
      task.invoke
      m = parsed_output['collections'].first['contents'].first
      expect(m).to include('type' => 'manifestation', 'id' => manifestation.id)
      expect(m['url']).to match(%r{/read/#{manifestation.id}})
    end

    it 'includes original_language as Hebrew text when not Hebrew' do
      task.invoke
      m = parsed_output['collections'].first['contents'].first
      expect(m['original_language']).to eq('אנגלית')
    end

    it 'omits original_language for Hebrew works' do
      manifestation.expression.work.update!(orig_lang: 'he')
      task.invoke
      m = parsed_output['collections'].first['contents'].first
      expect(m).not_to have_key('original_language')
    end
  end

  context 'with a qualifying periodical_issue collection' do
    let!(:manifestation) { create(:manifestation, status: :published) }
    let!(:collection) do
      create(:collection, collection_type: :periodical_issue, manifestations: [manifestation])
    end

    it 'includes periodical_issue collections' do
      task.invoke
      expect(parsed_output['collections'].map { |c| c['id'] }).to include(collection.id) # rubocop:disable Rails/Pluck
    end
  end

  context 'with tag filtering' do
    let!(:manifestation) { create(:manifestation, status: :published) }
    let!(:collection) do
      create(:collection, collection_type: :volume, manifestations: [manifestation])
    end
    let!(:approved_tag) { create(:tag, status: :approved) }

    before do
      create(:tagging, taggable: collection, tag: approved_tag, status: :approved)
    end

    it 'exports approved tags' do
      task.invoke
      expect(parsed_output['collections'].first['tags']).to eq([approved_tag.name])
    end

    it 'excludes tags whose tagging is pending' do
      pending_tagging_tag = create(:tag, status: :approved)
      create(:tagging, taggable: collection, tag: pending_tagging_tag, status: :pending)
      task.invoke
      expect(parsed_output['collections'].first['tags']).not_to include(pending_tagging_tag.name)
    end

    it 'excludes tags where the tag itself is not approved even if the tagging is approved' do
      pending_tag = create(:tag, status: :pending)
      create(:tagging, taggable: collection, tag: pending_tag, status: :approved)
      task.invoke
      expect(parsed_output['collections'].first['tags']).not_to include(pending_tag.name)
    end
  end

  context 'when filtering by collection type' do
    let!(:manifestation) { create(:manifestation, status: :published) }

    it 'excludes series collections' do
      series = create(:collection, collection_type: :series, manifestations: [manifestation])
      task.invoke
      ids = parsed_output['collections'].map { |c| c['id'] } # rubocop:disable Rails/Pluck
      expect(ids).not_to include(series.id)
    end

    it 'excludes collections with no published manifestations' do
      empty_col = create(:collection, collection_type: :volume)
      task.invoke
      ids = parsed_output['collections'].map { |c| c['id'] } # rubocop:disable Rails/Pluck
      expect(ids).not_to include(empty_col.id)
    end
  end

  context 'with authority serialization' do
    let!(:auth_z) { create(:authority, name: 'Zara Author') }
    let!(:auth_a) { create(:authority, name: 'Aaron Author') }
    let!(:manifestation) { create(:manifestation, status: :published, author: auth_z) }
    let!(:collection) do
      create(:collection, collection_type: :volume, manifestations: [manifestation])
    end

    before do
      manifestation.expression.work.involved_authorities.create!(role: :author, authority: auth_a)
    end

    it 'sorts authority names within each role' do
      task.invoke
      m = parsed_output['collections'].first['contents'].first
      expect(m['authorities']['author']).to eq(['Aaron Author', 'Zara Author'])
    end
  end

  context 'with nested sub-collections' do
    let!(:manifestation) { create(:manifestation, status: :published) }
    let!(:sub_collection) do
      create(:collection, collection_type: :volume, title: 'Sub Collection', manifestations: [manifestation])
    end
    let!(:parent_collection) do
      create(:collection, collection_type: :volume, title: 'Parent Collection',
                          included_collections: [sub_collection])
    end

    it 'includes the sub-collection in the parent contents tree' do
      task.invoke
      parent = parsed_output['collections'].find { |c| c['id'] == parent_collection.id }
      expect(parent).not_to be_nil
      nested = parent['contents'].find { |c| c['type'] == 'collection' }
      expect(nested).to include('id' => sub_collection.id, 'title' => 'Sub Collection')
    end

    it 'includes the manifestation nested inside the sub-collection' do
      task.invoke
      parent = parsed_output['collections'].find { |c| c['id'] == parent_collection.id }
      nested_col = parent['contents'].find { |c| c['type'] == 'collection' }
      expect(nested_col['contents'].first).to include('id' => manifestation.id)
    end
  end

  context 'with --all mode' do
    before { ENV['EXPORT_CATALOG_LIMIT'] = '2' }

    let!(:manifestations) { create_list(:manifestation, 3, status: :published) }
    let!(:collections) do
      manifestations.map do |m|
        create(:collection, collection_type: :volume, manifestations: [m])
      end
    end

    it 'uses "all collections and uncollected texts" as the mode label' do
      allow(ARGV).to receive(:include?).with('--all').and_return(true)
      task.invoke
      expect(parsed_output['mode']).to eq('all collections and uncollected texts')
    end

    it 'exports all qualifying collections beyond the default limit' do
      allow(ARGV).to receive(:include?).with('--all').and_return(true)
      task.invoke
      expect(parsed_output['count']).to eq(3)
    end

    it 'stops at the limit in default mode' do
      task.invoke
      expect(parsed_output['count']).to eq(2)
    end
  end

  context 'with uncollected texts' do
    let!(:uncollected_col) { create(:collection, :uncollected) }
    let!(:published_m) { create(:manifestation, status: :published, orig_lang: 'fr') }
    let!(:unpublished_m) { create(:manifestation, status: :unpublished) }

    before do
      uncollected_col.append_item(published_m)
      uncollected_col.append_item(unpublished_m)
    end

    it 'includes uncollected_texts and uncollected_count in the output' do
      task.invoke
      data = parsed_output
      expect(data).to include('uncollected_texts', 'uncollected_count')
    end

    it 'exports published manifestations from uncollected collections' do
      task.invoke
      ids = parsed_output['uncollected_texts'].map { |m| m['id'] } # rubocop:disable Rails/Pluck
      expect(ids).to include(published_m.id)
    end

    it 'excludes unpublished manifestations from uncollected collections' do
      task.invoke
      ids = parsed_output['uncollected_texts'].map { |m| m['id'] } # rubocop:disable Rails/Pluck
      expect(ids).not_to include(unpublished_m.id)
    end

    it 'serializes uncollected manifestations with the standard manifestation fields' do
      task.invoke
      m = parsed_output['uncollected_texts'].find { |x| x['id'] == published_m.id }
      expect(m).to include('type' => 'manifestation')
      expect(m.keys).to include('id', 'url', 'title', 'authorities', 'tags')
      expect(m['url']).to match(%r{/read/#{published_m.id}})
      expect(m['original_language']).to eq('צרפתית')
    end

    it 'includes source_edition and date for uncollected manifestations when present' do
      published_m.expression.update!(source_edition: 'First Ed.', date: '1920')
      task.invoke
      m = parsed_output['uncollected_texts'].find { |x| x['id'] == published_m.id }
      expect(m['source_edition']).to eq('First Ed.')
      expect(m['date']).to eq('1920')
    end

    it 'does not include source_edition and date for collected manifestations' do
      m_in_vol = create(:manifestation, status: :published)
      m_in_vol.expression.update!(source_edition: 'First Ed.', date: '1920')
      create(:collection, collection_type: :volume, manifestations: [m_in_vol])
      task.invoke
      collected = parsed_output['collections'].flat_map { |c| c['contents'] }
                                              .find { |x| x['id'] == m_in_vol.id }
      expect(collected).not_to have_key('source_edition')
      expect(collected).not_to have_key('date')
    end

    it 'does not include the uncollected collection itself in collections' do
      task.invoke
      ids = parsed_output['collections'].map { |c| c['id'] } # rubocop:disable Rails/Pluck
      expect(ids).not_to include(uncollected_col.id)
    end
  end

  context 'with uncollected limit' do
    let!(:uncollected_col) { create(:collection, :uncollected) }
    let!(:manifestations) { create_list(:manifestation, 3, status: :published) }

    before do
      ENV['EXPORT_CATALOG_LIMIT'] = '2'
      manifestations.each { |m| uncollected_col.append_item(m) }
    end

    it 'stops at the limit in default mode' do
      task.invoke
      expect(parsed_output['uncollected_count']).to eq(2)
    end

    it 'exports all uncollected texts in --all mode' do
      allow(ARGV).to receive(:include?).with('--all').and_return(true)
      task.invoke
      expect(parsed_output['uncollected_count']).to eq(3)
    end
  end
end
