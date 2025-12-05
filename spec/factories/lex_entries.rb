# frozen_string_literal: true

FactoryBot.define do
  factory :lex_entry, traits: %i(person) do
    title { Faker::Name.name }
    status { %w(draft published).sample }

    trait :person do
      lex_item { status.to_s == 'raw' ? nil : build(:lex_person) }
    end

    trait :publication do
      lex_item { status.to_s == 'raw' ? nil : build(:lex_publication) }
    end
  end
end
