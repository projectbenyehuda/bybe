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

    works do
      next_seqno = 1
      result = []
      works_count.times do
        result << build(:lex_person_work, person: nil, seqno: next_seqno)
        next_seqno += 1
      end
      result
    end
  end
end
