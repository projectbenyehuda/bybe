# frozen_string_literal: true

FactoryBot.define do
  factory :lex_citation_author do
    name { Faker::Book.author }
    link { Faker::Internet.url }
  end
end
