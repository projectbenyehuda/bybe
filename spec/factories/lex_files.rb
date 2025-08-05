FactoryBot.define do
  factory :lex_file do
    status { 'classified' }
    comments { Faker::Lorem.sentence }

    trait :person do
      fname { "/#{format('%05d', Faker::Number.between(from: 1, to: 99999))}.php" }
      entry_type { 'person' }
      title { Faker::Name.name }
    end

  end
end
