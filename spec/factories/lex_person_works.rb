# frozen_string_literal: true

FactoryBot.define do
  factory :lex_person_work do
    person { create(:lex_entry, :person).lex_item }
    publication_date { Random.rand(1950..2026).to_s }
    publication_place { Faker::Address.city }
    publisher { Faker::Name.name }
    title { Faker::Book.title }
    work_type { LexPersonWork.work_types.keys.sample }

    # Assign seqno automatically in factory
    seqno do
      max_seqno = LexPersonWork.where(lex_person_id: person.id, work_type: work_type).maximum(:seqno) || 0
      max_seqno + 1
    end
  end
end
