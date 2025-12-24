class ManifestationsIndex < Chewy::Index
  # works
  index_scope Manifestation.all_published.indexable.with_involved_authorities.preload(taggings: :tag)
#    field :title, analyzer: 'hebrew' # from https://github.com/synhershko/elasticsearch-analysis-hebrew
#    field :fulltext, value: ->(manifestation) {manifestation.to_plaintext}, analyzer: 'hebrew'
  field :id, type: 'integer'
  field :title
  field :primary, type: 'boolean', value: -> (manifestation) { manifestation.expression.work.primary }
  field :alternate_titles
  field :sort_title, type: 'keyword' # for sorting
  field :first_letter, value: ->(manifestation) {manifestation.first_hebrew_letter}
  field :fulltext, value: ->(manifestation) {manifestation.to_plaintext}
  field :genre, value: ->(manifestation) { manifestation.expression.work.genre}, type: 'keyword'
  field :orig_lang, value: ->(manifestation) { manifestation.expression.work.orig_lang}, type: 'keyword'
  field :orig_lang_title, value: ->(manifestation) { manifestation.expression.work.origlang_title}, type: 'keyword'
  field :pby_publication_date, type: 'date', value: ->{created_at}
  field :author_string, value: ->(manifestation) {manifestation.author_string}
  field :author_ids, type: 'integer', value: ->(manifestation) {manifestation.author_and_translator_ids}
  field :title_and_authors, value: ->(manifestation) {manifestation.title_and_authors}
  field :impressions_count, type: 'integer'
  field :raw_publication_date, value: -> (manifestation) {manifestation.expression.date}
  field :orig_publication_date, type: 'date', value: ->(manifestation) {normalize_date(manifestation.expression.date)}
    # field :video_count, type: 'integer', value: ->(manifestation){ manifestation.video_count}
    # field :recommendation_count, type: 'integer', value: ->(manifestation){manifestation.recommendations.all_approved.count}
    #field :curated_content_count, type: 'integer', value: ->(manifestation){ 0 } # TODO: implement
  field :tags, type: 'keyword', value: ->{ approved_tags.map(&:name) }
  field :author_gender, value: ->(manifestation) {manifestation.author_gender }, type: 'keyword'
  field :translator_gender, value: ->(manifestation) {manifestation.translator_gender}, type: 'keyword'
  field :intellectual_property,
        value: ->(manifestation) { manifestation.expression.intellectual_property }, type: 'keyword'
  field :period, value: ->(manifestation) {manifestation.expression.period}, type: 'keyword'
  field :raw_creation_date, value: ->(manifestation) {manifestation.expression.work.date}
  field :creation_date, type: 'date', value: ->(manifestation) {normalize_date(manifestation.expression.work.date)}
  field :publication_place
  field :publisher
  field :in_volume, type: 'boolean', value: ->(manifestation) { manifestation.in_volume? }
  field :in_periodical, type: 'boolean', value: ->(manifestation) { manifestation.in_periodical? }

  # TODO: in future: collections/readers; users; recommendations; curated/featured content
end
