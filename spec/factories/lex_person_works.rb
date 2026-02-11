# frozen_string_literal: true

FactoryBot.define do
  sequence(:lex_person_work_seqno) { |n| n }

  factory :lex_person_work do
    person { create(:lex_entry, :person).lex_item }
    publication_date { Random.rand(1950..2026).to_s }
    publication_place { Faker::Address.city }
    publisher { Faker::Name.name }
    title { Faker::Book.title }
    work_type { LexPersonWork.work_types.keys.sample }

    # Assign seqno automatically in factory
    seqno do
      generate(:lex_person_work_seqno)
    end
  end
end
