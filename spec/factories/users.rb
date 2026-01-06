FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    provider { 'google_oauth2' }
    admin { false }
    editor { false }

    trait :edit_catalog do
      editor { true }
      after :create do |user|
        create(:list_item, item: user, listkey: :edit_catalog)
      end
    end

    trait :bib_workshop do
      editor { true }
      after :create do |user|
        create(:list_item, item: user, listkey: :bib_workshop)
      end
    end
    trait :admin do
      admin { true }
    end

    trait :moderate_links do
      editor { true }
      after :create do |user|
        create(:list_item, item: user, listkey: :moderate_links)
      end
    end
  end
end
