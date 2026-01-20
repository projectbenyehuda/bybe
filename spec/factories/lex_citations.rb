# frozen_string_literal: true

FactoryBot.define do
  factory :lex_citation do
    transient do
      authors_count { 1 }
    end

    title { Faker::Book.title }
    from_publication { Faker::Book.title }
    authors { build_list(:lex_citation_author, authors_count) }
    pages { Random.rand(1..100).to_s }
    link { Faker::Internet.url }
  end
end
