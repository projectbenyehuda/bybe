# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    title { Faker::Book.title }
    sort_title { title }
    subtitle { Faker::Book.title }
    issn { 'MyString' }
    collection_type { %w(volume periodical periodical_issue series other).sample }

    # Trait for creating system-managed uncollected collections
    trait :uncollected do
      collection_type { :uncollected }
      after(:build) do |collection|
        collection.allow_system_type_change!
      end
    end

    transient do
      authors { [] }
      translators { [] }
      editors { [] }
      included_collections { [] }
      manifestations { [] }
      title_placeholders { [] }
      markdown_placeholders { [] }
    end

    involved_authorities do
      result = []
      if authors.present?
        result += authors.map { |authority| build(:involved_authority, authority: authority, role: :author) }
      end
      if translators.present?
        result += translators.map { |authority| build(:involved_authority, authority: authority, role: :translator) }
      end
      if editors.present?
        result += editors.map { |authority| build(:involved_authority, authority: authority, role: :editor) }
      end
      result
    end

    collection_items do
      i = 0
      (included_collections + manifestations).map { |item| build(:collection_item, item: item, seqno: i += 1) } +
        title_placeholders.map { |title| build(:collection_item, alt_title: title, seqno: i += 1) } +
        markdown_placeholders.map { |markdown| build(:collection_item, markdown: markdown, seqno: i += 1) }
    end
  end
end
