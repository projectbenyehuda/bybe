# frozen_string_literal: true

FactoryBot.define do
  factory :lex_legacy_link do
    old_path { "files-#{Random.next(min: 100, max: 999)}/#{Faker::File.file_name}" }
    new_path { "/#{Faker::File.file_name}" }
  end
end
