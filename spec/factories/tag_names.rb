FactoryBot.define do
  factory :tag_name do
    tag { create(:tag) }
    sequence(:name) { |n| "Tag Name #{n}" }
  end
end
