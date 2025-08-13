# frozen_string_literal: true

FactoryBot.define do
  factory :lex_publication do
    description { Faker::Lorem.paragraph }
    toc { Faker::Lorem.paragraph }
    az_navbar { Faker::Boolean.boolean }
  end
end
