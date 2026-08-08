# frozen_string_literal: true

module V1
  module Entities
    # API representation for Authority objects
    class Authority < Grape::Entity
      expose :id, documentation: { type: :Integer }
      expose :url, documentation: {
        desc: 'Canonical URL of the person at Project Ben-Yehuda (useful for giving credit and allowing' \
              'users to click through). Null for authorities that have no page of their own, such as ' \
              "'anonymous' or 'various authors'."
      } do |au|
        au.pageless? ? nil : Rails.application.routes.url_helpers.authority_url(au)
      end
      expose :metadata do
        expose :name
        expose :sort_name, documentation: { desc: 'version of the name more useful for alphabetical sorting' }
        expose :other_designation,
               as: :other_designations,
               documentation: { desc: 'semicolon-separated list of additional names or spellings for this authority' }
        expose :intellectual_property, documentation: { values: ::Authority.intellectual_properties.keys }
        expose :person,
               using: V1::Entities::Person,
               expose_nil: false,
               documentation: { desc: 'person-specific data (omitted for corporate bodies)' }
        expose :corporate_body,
               using: V1::Entities::CorporateBody,
               expose_nil: false,
               documentation: { desc: 'corporate bodies-specific data (omitted for people)' }
        expose :wikipedia_snippet, as: :bio_snippet
        expose :all_languages,
               as: :languages,
               documentation: {
                 type: 'String', is_array: true, desc: 'list of languages (by ISO code) this authirity worked in'
               }
        expose :all_genres, as: :genres, documentation: { values: Work::GENRES, is_array: true }
        expose :impressions_count,
               documentation: {
                 type: 'Integer',
                 desc: "total number of times the authority's page OR one of their texts were viewed or printed"
               }
      end

      expose :texts,
             documentation: { desc: 'ID numbers of all texts this authority is involved in, with role in each' },
             if: ->(_au, options) { %w(texts enriched).include?(options[:detail]) } do
               InvolvedAuthority.roles.each_key do |role|
                 expose role, documentation: { type: 'Integer', is_array: true } do |au|
                   au.published_manifestations(role).pluck('manifestations.id').sort
                 end
               end
             end

      expose :enrichment, if: ->(_au, options) { %w(enriched).include? options[:detail] } do
        expose :texts_about,
               documentation: {
                 type: 'Integer', is_array: true,
                 desc: 'ID numbers of texts whose subject is this person'
               } do |au|
          Aboutness.where(aboutable: au)
                   .joins(work: { expressions: :manifestations })
                   .pluck('manifestations.id').sort
        end
      end
    end
  end
end
