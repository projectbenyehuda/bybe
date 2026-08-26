require 'rails_helper'

describe Tag do
  before do
    Faker::UniqueGenerator.clear
  end

  it 'considers invalid an empty tag' do
    t = Tag.new
    expect(t).not_to be_valid
  end

  it 'considers valid tag with minimal attributes set' do
    t = Tag.new(name: Faker::Science.unique.science, creator: create(:user), status: 'pending')
    expect(t).to be_valid
  end

  it 'has a valid factory' do
    expect(build(:tag)).to be_valid
  end

  # by-7lw: the factory used to draw names from Faker::Lorem.unique.word, a finite 249-word pool,
  # so past that many tags every create(:tag) in the process raised RetryLimitExceeded. 300 is
  # deliberately over that old ceiling.
  it 'generates factory tag names from an unbounded pool' do
    creator = create(:user) # shared, so this measures name generation and not user creation
    names = Array.new(300) { build(:tag, creator: creator).name }
    expect(names.uniq.size).to eq 300
  end

  it 'finds tags by creator' do
    u = create(:user)
    i = 0
    3.times do
      t = Tag.new(name: "#{Faker::Science.unique.science} #{i} #{rand(1000)}", creator: u, status: 'pending')
      t.save
      i += 1
    end
    2.times do
      t = Tag.new(name: "#{Faker::Science.unique.science} #{i} #{rand(1000)}", creator: create(:user),
                  status: 'pending')
      t.save
      i += 1
    end
    expect(Tag.by_user(u).count).to eq 3
  end

  it 'fetches only approved tags' do
    u = create(:user)
    i = 0
    5.times do
      t = Tag.new(name: "#{Faker::Science.unique.science} #{i} #{rand(1000)}", creator: u, status: 'pending')
      t.save
      i += 1
    end
    u2 = create(:user)
    Tag.last(2).each do |tag|
      tag.approve!(u2)
    end
    expect(Tag.approved.count).to eq 2
  end

  it 'fetches only pending tags' do
    u = create(:user)
    i = 0
    5.times do
      t = Tag.new(name: "#{Faker::Science.unique.science} #{i} #{rand(1000)}", creator: u, status: 'pending')
      t.save
      i += 1
    end
    u2 = create(:user)
    Tag.last(2).each do |tag|
      tag.approve!(u2)
    end
    expect(Tag.pending.count).to eq 3
  end

  it 'approves a tag' do
    t = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'pending')
    expect(Tag.last.status).to eq 'pending'
    u = create(:user)
    t.approve!(u)
    expect(Tag.last.status).to eq 'approved'
  end

  it 'rejects and blacklists a tag' do
    t = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'pending')
    expect(Tag.last.status).to eq 'pending'
    u = create(:user)
    t.reject!(u)
    expect(Tag.last.status).to eq 'rejected'
  end

  it 'links to tagged manifestation via approved taggings' do
    t = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    5.times do
      Tagging.create!(tag: t, taggable: create(:manifestation), suggester: create(:user), status: 'approved')
    end
    t2 = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    5.times do
      Tagging.create!(tag: t2, taggable: create(:manifestation), suggester: create(:user), status: 'pending')
    end
    expect(Tagging.all.count).to eq 10
    expect(t.taggings.count).to eq 5
    expect(t.manifestation_taggings.count).to eq 5
    expect(t2.taggings.count).to eq 5
    expect(t2.manifestation_taggings.count).to eq 5
    expect(t2.manifestation_taggings.approved.count).to eq 0
  end

  describe 'taggings scopes' do
    let(:first) do
      described_class.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    end

    let(:second) do
      described_class.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    end

    before do
      5.times do
        Tagging.create!(tag: first, taggable: create(:manifestation), suggester: create(:user), status: 'approved')
      end
      5.times do
        Tagging.create!(tag: first, taggable: create(:manifestation), suggester: create(:user), status: 'pending')
      end
      5.times do
        Tagging.create!(tag: first, taggable: create(:authority), suggester: create(:user), status: 'approved')
      end
      3.times do
        Tagging.create!(tag: first, taggable: create(:authority), suggester: create(:user), status: 'pending')
      end
      5.times do
        Tagging.create!(tag: second, taggable: create(:manifestation), suggester: create(:user), status: 'pending')
      end
    end

    it 'links to tagged items of all kinds via approved taggings' do
      expect(Tagging.count).to eq 23
      expect(first.taggings.count).to eq 18
      expect(first.manifestation_taggings.count).to eq 10
      expect(first.authority_taggings.count).to eq 8
      expect(first.authority_taggings.approved.count).to eq 5
      expect(first.taggings.approved.count).to eq 10
      expect(first.manifestation_taggings.approved.count).to eq 5
      expect(second.taggings.count).to eq 5
      expect(second.manifestation_taggings.count).to eq 5
      expect(second.manifestation_taggings.approved.count).to eq 0
    end
  end

  it 'deletes taggings when tag is deleted' do
    t = Tag.create!(name: "#{Faker::Science.unique.science} #{rand(1000)}", creator: create(:user), status: 'approved')
    5.times do
      Tagging.create!(tag: t, taggable: create(:manifestation), suggester: create(:user), status: 'pending')
    end
    expect(Tag.last.taggings.count).to eq 5
    t.destroy
    expect(Tagging.count).to eq 0
  end

  it 'finds tags by TagName' do
    u = create(:user)
    i = 0
    5.times do
      t = Tag.new(name: "#{Faker::Science.unique.science} #{i} #{rand(1000)}", creator: u, status: 'pending')
      t.save
      i += 1
    end
    t = Tag.last
    tn = t.name + '_alias'
    TagName.create!(name: tn, tag: t)
    expect(TagName.last.tag).to eq t
    expect(TagName.last.name).to eq tn
    expect(TagName.where(name: tn).count).to eq 1
    expect(TagName.where(name: t.name).count).to eq 1
  end

  it 'merges tag into another tag, including tag_names and taggings' do
    t = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    5.times do
      Tagging.create!(tag: t, taggable: create(:manifestation), suggester: create(:user), status: 'pending')
      TagName.create!(name: Faker::Science.unique.science, tag: t)
    end
    expect(Tag.last.taggings.count).to eq 5
    expect(Tag.last.tag_names.count).to eq 6 # including one created upon tag creation
    t2 = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    5.times do
      Tagging.create!(tag: t2, taggable: create(:manifestation), suggester: create(:user), status: 'pending')
      TagName.create!(name: Faker::Science.unique.science, tag: t)
    end
    expect(Tagging.count).to eq 10
    expect(TagName.count).to eq 12
    tid = t.id
    t.merge_into(t2)
    expect(Tag.find_by(id: tid)).to be_nil # should be destroyed by the merge
    expect(Tag.count).to eq 1
    expect(t2.taggings.count).to eq 10
    expect(t2.tag_names.count).to eq 12
  end

  it 'merges tag into another tag, but does not create duplicate taggings' do
    t = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    5.times { Tagging.create!(tag: t, taggable: create(:manifestation), suggester: create(:user), status: 'pending') }
    expect(Tag.last.taggings.count).to eq 5
    t2 = Tag.create!(name: Faker::Science.unique.science, creator: create(:user), status: 'approved')
    5.times do
      Tagging.create!(tag: t2, taggable: create(:manifestation), suggester: create(:user), status: 'pending')
    end
    Tagging.create!(tag: t2, taggable: t.taggings.last.taggable, suggester: create(:user),
                    status: 'pending') # create a tagging that would be a duplicate after merge
    expect(Tagging.count).to eq 11
    tid = t.id
    t.merge_into(t2)
    expect(Tag.find_by(id: tid)).to be_nil # should be destroyed by the merge
    expect(Tag.count).to eq 1
    expect(t2.taggings.count).to eq 10 # duplicate removed
  end
end
