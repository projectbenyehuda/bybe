# frozen_string_literal: true

FactoryBot.define do
  sequence(:lex_person_work_group_title) { |n| "כותרת משנה של יצירות #{n}" }

  factory :lex_person_work_group do
    person { create(:lex_entry, :person).lex_item }
    work_type { 'original' }
    title { generate(:lex_person_work_group_title) }
  end
end
