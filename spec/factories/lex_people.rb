# frozen_string_literal: true

FactoryBot.define do
  factory :lex_person do
    transient do
      works_count { 0 }
    end
    aliases { Faker::Name.name }
    copyrighted { [true, false].sample }
    birthdate { Faker::Date.birthday(min_age: 50, max_age: 100).to_fs }
    deathdate { Faker::Date.birthday(min_age: 80, max_age: 0).to_fs }
    bio { Faker::Lorem.paragraph }

    after(:create) do |lex_person, evaluator|
      create_list(:lex_person_work, evaluator.works_count, person: lex_person) if evaluator.works_count.positive?
    end
  end
end
