# frozen_string_literal: true

FactoryBot.define do
  factory :static_page do
    title { Faker::Book.title }
    tag { Faker::Name.first_name }
    body { Faker::Lorem.paragraph }
    status { 'published' }
    mode { 'plain_markdown' }
  end
end
