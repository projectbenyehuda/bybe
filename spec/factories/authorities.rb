# frozen_string_literal: true

FactoryBot.define do
  factory :authority do
    transient do
      gender { 'male' }
      period { 'revival' }
    end

    name { Faker::Name.name }
    status { :published }
    other_designation { Faker::Name.name_with_middle }
    wikipedia_snippet { Faker::Quotes::Shakespeare.hamlet_quote }
    impressions_count { Random.rand(200) }
    intellectual_property { :public_domain }

    person { create(:person, gender: gender, period: period) if corporate_body.nil? }

    trait :corporate_body do
      corporate_body { create(:corporate_body) }
    end

    trait :with_image do
      profile_image_file_name { 'test_image.jpg' }
    end
  end
end
