# frozen_string_literal: true

require 'rails_helper'

# Regression coverage for the /collections browse "filter by authors" multiselect.
#
# The popup writes a comma-separated list of authority ids into the hidden
# `authorities` field and submits the filters form; the controller parses it back
# with `split(',')`. If the re-rendered hidden field does not round-trip in that
# same comma-separated form, the filter silently degrades on the *next* filter
# interaction (e.g. typing a title, ticking a collection type).
RSpec.describe 'Collections browse - authorities filter', type: :request do
  let!(:alice) { create(:authority, name: 'Alice Author') }
  let!(:bob) { create(:authority, name: 'Bob Author') }
  let!(:carol) { create(:authority, name: 'Carol Author') }

  let!(:alice_volume) do
    create(:collection, title: 'Alice Volume', collection_type: :volume, sort_title: 'alice volume').tap do |c|
      c.involved_authorities.create!(authority: alice, role: :author)
    end
  end
  let!(:bob_volume) do
    create(:collection, title: 'Bob Volume', collection_type: :volume, sort_title: 'bob volume').tap do |c|
      c.involved_authorities.create!(authority: bob, role: :author)
    end
  end
  let!(:carol_volume) do
    create(:collection, title: 'Carol Volume', collection_type: :volume, sort_title: 'carol volume').tap do |c|
      c.involved_authorities.create!(authority: carol, role: :author)
    end
  end

  # The popup's JS emits a trailing comma ("1,2,"), so exercise that exact shape.
  let(:authorities_param) { "#{alice.id},#{bob.id}," }

  before do
    import_and_await(CollectionsIndex, [alice_volume, bob_volume, carol_volume])
  end

  after do
    Chewy.massacre
  end

  it 'filters the list down to collections of the selected authorities' do
    get collections_browse_path, params: { authorities: authorities_param }

    expect(response.body).to include('Alice Volume')
    expect(response.body).to include('Bob Volume')
    expect(response.body).not_to include('Carol Volume')
  end

  it 'round-trips the selection into the hidden field as a comma-separated list' do
    get collections_browse_path, params: { authorities: authorities_param }

    hidden_value = response.body[/id="authority_ids" value="([^"]*)"/, 1] ||
                   response.body[/name="authorities"[^>]*value="([^"]*)"/, 1]

    expect(hidden_value).to be_present
    expect(hidden_value.split(',').map(&:to_i)).to contain_exactly(alice.id, bob.id)
  end

  it 'retains all selected authorities when another filter is subsequently applied' do
    # Simulate the second round-trip: the browser resubmits whatever the hidden
    # field was re-rendered with, alongside the newly changed filter.
    get collections_browse_path, params: { authorities: authorities_param }
    resubmitted = response.body[/id="authority_ids" value="([^"]*)"/, 1]

    get collections_browse_path, params: { authorities: resubmitted, ckb_collection_types: ['volume'] }

    expect(response.body).to include('Alice Volume')
    expect(response.body).to include('Bob Volume')
    expect(response.body).not_to include('Carol Volume')
  end

  it 'keeps the selected authorities checked in the multiselect popup' do
    get collections_browse_path, params: { authorities: authorities_param }

    # Haml emits attributes in alphabetical order, so `checked` precedes `id`.
    checkboxes = response.body.scan(/<input[^>]*name="ckb_authorities\[\]"[^>]*>/)
    checked_ids = checkboxes.grep(/checked/).map { |tag| tag[/value="(\d+)"/, 1].to_i }

    expect(checked_ids).to contain_exactly(alice.id, bob.id)
  end
end
