# frozen_string_literal: true

FactoryBot.define do
  factory :saved_selection do
    delete_after { Time.zone.today + 3.days }
    name { Faker::Book.title }
    user { create(:user) }
    shared { false }

    transient do
      items_count { 2 }
    end

    saved_selection_items { build_list(:saved_selection_item, items_count) }
  end
end
