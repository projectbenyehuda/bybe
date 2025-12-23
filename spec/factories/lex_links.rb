# frozen_string_literal: true

FactoryBot.define do
  factory :lex_link do
    url { Faker::Internet.url }
    description { Faker::Lorem.sentence }
    status { nil }
    item factory: :lex_person
  end
end
