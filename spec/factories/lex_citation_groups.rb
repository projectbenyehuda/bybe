# frozen_string_literal: true

FactoryBot.define do
  sequence(:lex_citation_group_title) { |n| "כותרת משנה #{n}" }

  factory :lex_citation_group do
    person factory: :lex_person
    title { generate(:lex_citation_group_title) }
  end
end
