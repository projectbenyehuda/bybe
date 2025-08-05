# frozen_string_literal: true

FactoryBot.define do
  factory :lex_file do
    status { 'classified' }
    comments { Faker::Lorem.sentence }

    trait :person do
      fname { "/#{format('%05d', Faker::Number.between(from: 1, to: 99_999))}.php" }
      title { Faker::Name.name }

      entrytype { 'person' }
      lex_entry do
        status&.to_s == 'ingested' ? create(:lex_entry, :person, status: :migrated) : nil
      end
    end
  end
end
