# frozen_string_literal: true

FactoryBot.define do
  factory :ahoy_event, class: 'Ahoy::Event' do
    visit { create(:ahoy_visit, started_at: time - 10.seconds) }
    name { Ahoy::Event::ALLOWED_NAMES.sample }
    time { Time.now - Random.rand(240).minutes }

    transient do
      controller { 'welcome' }
      action { 'index' }
    end

    properties { { controller: controller, action: action } }

    trait :with_item do
      transient do
        item { create(:authority) }
        # Only download events carry a file format
        doctype { nil }
      end

      controller { item.class.name.pluralize }
      action { name }

      properties do
        props = { id: item.id, type: item.class.name, controller: controller, action: action }
        props[:format] = doctype if doctype.present?
        props
      end
    end
  end
end
