# frozen_string_literal: true

FactoryBot.define do
  factory :saved_selection_item do
    item { create(:manifestation) }
  end
end
