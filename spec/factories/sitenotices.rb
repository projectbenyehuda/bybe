# frozen_string_literal: true

FactoryBot.define do
  factory :sitenotice do
    body { Faker::Lorem.sentence }
    status { :enabled }
    fromdate { 1.day.ago }
    todate { 1.day.from_now }
  end
end
