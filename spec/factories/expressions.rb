FactoryBot.define do
  factory :expression do
    transient do
      sequence(:expression_name) { |n| "Expression #{n}" }
      author { create(:authority) }
      orig_lang { %w(he en ru de it).sample }
      translator { orig_lang.to_s == 'he' ? nil : create(:authority) }
      editor { nil }
      illustrator { nil }
      genre { Work::GENRES.sample }
      work_title { title }
      primary { true }
      work_date { '3 ביוני 1960' }
    end
    title { "Title for #{expression_name}" }
    form {}
    date { '2 ביוני 1960' }
    language { 'he' }
    comment { "Comment for #{expression_name}" }
    intellectual_property { :public_domain }
    copyright_expiration { nil }
    translation { orig_lang != language }
    source_edition {}
    period { Expression.periods.keys.sample }
    work do
      create(
        :work,
        genre: genre,
        author: author,
        illustrator: illustrator,
        orig_lang: orig_lang,
        date: work_date,
        primary: primary
      )
    end
    involved_authorities do
      result = []
      if orig_lang.to_s == language.to_s
        if translator.present?
          raise 'Cannot specify translator if language matches orig_lang'
        end
      else
        result << build(:involved_authority, authority: translator, role: :translator)
      end
      if editor.present?
        result << build(:involved_authority, authority: editor, role: :editor)
      end
      result
    end
  end
end
