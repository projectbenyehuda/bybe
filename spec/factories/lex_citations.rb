# frozen_string_literal: true

FactoryBot.define do
  factory :lex_citation do
    title { 'MyString' }
    from_publication { 'MyString' }
    authors { 'MyString' }
    pages { 'MyString' }
    link { 'MyString' }
    item { nil }
    manifestation { nil }
  end
end
