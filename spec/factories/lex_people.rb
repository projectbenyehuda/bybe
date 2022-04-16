FactoryBot.define do
  factory :lex_person do
    aliases { "MyString" }
    copyrighted { false }
    birthdate { "MyString" }
    deathdate { "MyString" }
    bio { "MyText" }
    works { "MyText" }
    about { "MyText" }
  end
end
