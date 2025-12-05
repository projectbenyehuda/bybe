# frozen_string_literal: true

FactoryBot.define do
  factory :lex_file, traits: %i(person) do
    status { 'classified' }
    comments { Faker::Lorem.sentence }

    transient do
      entry_status { 'draft' }

      title do
        case entrytype
        when 'person' then Faker::Name.name
        when 'text' then Faker::Book.title
        end
      end
    end

    trait :person do
      fname { "#{format('%05d', Faker::Number.between(from: 1, to: 99_999))}.php" }

      entrytype { 'person' }
      lex_entry { create(:lex_entry, :person, status: entry_status, title: title) }
    end

    trait :publication do
      fname { "#{format('%08d', Faker::Number.between(from: 1, to: 99_999_999))}.php" }

      entrytype { 'text' }
      lex_entry { create(:lex_entry, :publication, status: entry_status, title: title) }
    end
  end
end
