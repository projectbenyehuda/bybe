# frozen_string_literal: true

require 'rails_helper'

# Regression coverage for the /works browse "filter by authors" multiselect.
#
# The popup writes a comma-separated list of author ids into the hidden `authors`
# field and submits the filters form; the controller parses it back with
# `split(',')`. If the re-rendered hidden field does not round-trip in that same
# comma-separated form, the selection silently collapses to its first id on the
# next filter interaction -- which also makes any subsequently added filter (genre,
# period, ...) appear broken, since it is then combined with the wrong author set.
RSpec.describe 'Works browse - authors filter', type: :request do
  let!(:alice) { create(:authority, name: 'Alice Author') }
  let!(:bob) { create(:authority, name: 'Bob Author') }

  let!(:alice_poem) { create_work(alice, 'Alice Poem', :poetry) }
  let!(:bob_prose) { create_work(bob, 'Bob Prose', :prose) }

  # The popup's JS emits a trailing comma ("1,2,"), so exercise that exact shape.
  let(:authors_param) { "#{alice.id},#{bob.id}," }

  before do
    import_and_await(ManifestationsIndex, [alice_poem, bob_prose])
  end

  after do
    Chewy.massacre
  end

  def create_work(authority, title, genre)
    create(:manifestation, title: title, genre: genre).tap do |m|
      m.expression.work.involved_authorities.create!(authority: authority, role: :author)
    end
  end

  it 'round-trips the selection into the hidden field as a comma-separated list' do
    get works_path, params: { authors: authors_param }

    hidden_value = response.body[/id="author_ids" value="([^"]*)"/, 1]

    expect(hidden_value).to be_present
    expect(hidden_value.split(',').map(&:to_i)).to contain_exactly(alice.id, bob.id)
  end

  it 'keeps all selected authors when a genre filter is subsequently added' do
    # Simulate the second round-trip: the browser resubmits whatever the hidden
    # field was re-rendered with, alongside the newly ticked genre checkbox.
    get works_path, params: { authors: authors_param }
    resubmitted = response.body[/id="author_ids" value="([^"]*)"/, 1]

    get works_path, params: { authors: resubmitted, ckb_genres: ['prose'] }

    # Bob's prose is only reachable if Bob survived the round-trip; before the fix
    # the author set collapsed to Alice alone and this list came back empty.
    expect(response.body).to include('Bob Prose')
    expect(response.body).not_to include('Alice Poem')
  end
end
