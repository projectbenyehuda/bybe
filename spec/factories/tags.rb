# frozen_string_literal: true

FactoryBot.define do
  factory :tag do
    status { :approved }
    # by-7lw: NOT Faker::Lorem.unique.word -- that pool is 249 words wide and is never reset, so
    # the 250th create(:tag) in a suite run raised RetryLimitExceeded, wherever it fell. Padded so
    # that no name is a substring of another ('tag-0001' vs 'tag-0011'), which specs searching a
    # rendered body for a tag name would otherwise miscount.
    sequence(:name) { |n| format('tag-%04d', n) }
    creator { create(:user) }
  end

  trait :pending do
    status { :pending }
  end
end

