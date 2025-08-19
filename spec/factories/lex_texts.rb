# frozen_string_literal: true

FactoryBot.define do
  factory :lex_text do
    title { 'MyString' }
    authors { 'MyString' }
    pages { 'MyString' }
    lex_publication { nil }
    lex_issue { nil }
    manifestation { nil }
  end
end
