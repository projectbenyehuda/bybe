# frozen_string_literal: true

FactoryBot.define do
  factory :dictionary_entry do
    manifestation
    sequence(:sequential_number) { |n| n }
    defhead { Faker::Book.title }
    sort_defhead { defhead }
    deftext { Faker::Quotes::Shakespeare.hamlet_quote }
  end
end
