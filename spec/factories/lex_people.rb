FactoryBot.define do
  factory :lex_person do
    aliases { Faker::Name.name }
    copyrighted { [true, false].sample }
    birthdate { Faker::Date.birthday(min_age: 50, max_age: 100).to_fs }
    deathdate { Faker::Date.birthday(min_age: 80, max_age: 0).to_fs }
    bio { Faker::Lorem.paragraph }
    works { Faker::Lorem.paragraph }
    about { Faker::Lorem.sentence }
  end
end
