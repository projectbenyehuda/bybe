# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    name { 'Test Project' }
    description { 'A test project description' }
    start_date { Date.current - 1.month }
    end_date { nil } # Active by default
    contact_person_name { 'John Doe' }
    contact_person_phone { '050-1234567' }
    contact_person_email { 'john@example.com' }
    comments { 'Project comments' }
    default_external_link { 'https://example.com' }
    default_link_description { 'Project Website' }

    trait :inactive do
      end_date { Date.current - 1.day }
    end

    trait :future_end_date do
      end_date { Date.current + 1.month }
    end
  end
end
