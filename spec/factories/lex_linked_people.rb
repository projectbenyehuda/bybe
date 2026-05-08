# frozen_string_literal: true

FactoryBot.define do
  sequence(:lex_linked_person_seqno) { |n| n }

  factory :lex_linked_person do
    person_work { create(:lex_person_work) }
    name { Faker::Name.name if person_entry.nil? }
    link_type { LexLinkedPerson.link_types.keys.sample }
    seqno { generate(:lex_linked_person_seqno) }
  end
end
