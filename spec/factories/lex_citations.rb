# frozen_string_literal: true

FactoryBot.define do
  sequence(:lex_citation_seqno) { |n| n }

  factory :lex_citation do
    transient do
      authors_count { 1 }
    end

    title { Faker::Book.title }
    from_publication { Faker::Book.title }
    authors { build_list(:lex_citation_author, authors_count) }
    pages { Random.rand(1..100).to_s }
    link { Faker::Internet.url }

    # Assign seqno automatically in factory (it only guranteesuniqieness of values)
    seqno do
      generate(:lex_citation_seqno)
    end
  end
end
