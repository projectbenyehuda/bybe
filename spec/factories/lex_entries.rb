# frozen_string_literal: true

FactoryBot.define do
  factory :lex_entry do
    title { Faker::Name.name }
    status { %w(migrated manual).sample }

    trait :person do
      lex_item { build(:lex_person) }
    end
  end
end
