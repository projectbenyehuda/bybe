FactoryBot.define do
  factory :external_link do
    url { Faker::Internet.url }
    linktype { ExternalLink.linktypes.values.sample }
    status { ExternalLink.statuses.values.sample }
    description { "Description for #{url}" }
    association :linkable, factory: :authority
  end
end