# frozen_string_literal: true

FactoryBot.define do
  factory :lex_person_work do
    publication_date { Random.rand(1950..2026).to_s }
    publication_place { Faker::Address.city }
    publisher { Faker::Name.name }
    title { Faker::Book.title }
    work_type { LexPersonWork.work_types.keys.sample }
  end
end
