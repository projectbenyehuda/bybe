# frozen_string_literal: true

FactoryBot.define do
  factory :lex_citation do
    title { item&.entry&.title || Faker::Book.title }
    from_publication { Faker::Book.title }
    authors { Faker::Name.name }
    pages { Random.rand(1..100).to_s }
    link { Faker::Internet.url }
    status { 'manual' }
  end
end
