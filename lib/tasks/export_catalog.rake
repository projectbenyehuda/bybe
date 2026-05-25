# frozen_string_literal: true

require 'json'
require 'bybe_utils'

# rubocop:disable Style/Documentation
module ExportCatalogHelpers
  # rubocop:enable Style/Documentation
  include BybeUtils

  def approved_tag_names(taggable)
    taggable.taggings.preload(:tag).select(&:approved?).select { |t| t.tag.approved? }.map { |t| t.tag.name }
  end

  def authorities_by_role(record)
    result = {}
    InvolvedAuthority.roles.each_key do |role|
      auths = record.involved_authorities_by_role(role)
      result[role] = auths.map(&:name).sort unless auths.empty?
    end
    result
  end

  def split_alternate_titles(raw)
    return [] if raw.blank?

    raw.split(';').map(&:strip).compact_blank
  end

  def serialize_manifestation(manifestation, url_helpers)
    lang = manifestation.expression.work.orig_lang
    entry = {
      type: 'manifestation',
      id: manifestation.id,
      url: url_helpers.manifestation_url(manifestation),
      title: manifestation.title,
      authorities: authorities_by_role(manifestation),
      tags: approved_tag_names(manifestation)
    }
    alts = split_alternate_titles(manifestation.alternate_titles)
    entry[:alternate_titles] = alts unless alts.empty?
    entry[:original_language] = textify_lang(lang) unless lang.blank? || lang == 'he'
    entry
  end

  def serialize_collection(collection, url_helpers, visited_ids)
    entry = {
      type: 'collection',
      id: collection.id,
      url: url_helpers.collection_url(collection),
      title: collection.title,
      authorities: authorities_by_role(collection),
      tags: approved_tag_names(collection),
      contents: serialize_contents(collection.collection_items, url_helpers, visited_ids)
    }
    entry[:subtitle] = collection.subtitle if collection.subtitle.present?
    alts = split_alternate_titles(collection.alternate_titles)
    entry[:alternate_titles] = alts unless alts.empty?
    entry[:publisher_line] = collection.publisher_line if collection.publisher_line.present?
    entry
  end

  def serialize_contents(collection_items, url_helpers, visited_ids)
    items = []
    collection_items.each do |ci|
      next unless ci.item_type.in?(%w(Manifestation Collection))
      next if ci.item.nil?

      if ci.item_type == 'Manifestation'
        items << serialize_manifestation(ci.item, url_helpers)
      else
        next if visited_ids.include?(ci.item_id)

        items << serialize_collection(ci.item, url_helpers, visited_ids + [ci.item_id])
      end
    end
    items
  end
end

desc 'Export catalog as JSON. Default: first 50 qualifying collections. Pass --all to export everything.'
task export_catalog: :environment do
  extend ExportCatalogHelpers

  all_mode = ARGV.include?('--all')
  limit = ENV.fetch('EXPORT_CATALOG_LIMIT', '50').to_i
  output_file = ENV.fetch('EXPORT_CATALOG_OUTPUT', 'catalog_export.json')
  mode_label = all_mode ? 'all collections' : "first #{limit} qualifying collections"

  puts "Mode: #{mode_label}"

  url_helpers = Rails.application.routes.url_helpers
  count = 0

  File.open(output_file, 'w:UTF-8') do |f|
    f.write("{\n  \"mode\": #{JSON.generate(mode_label)},\n  \"collections\": [\n")
    first = true

    Collection
      .where(collection_type: %i(volume periodical_issue))
      .preload({ taggings: :tag }, { involved_authorities: :authority })
      .find_each do |collection|
        next unless collection.any_published_manifestations?

        serialized = serialize_collection(collection, url_helpers, [collection.id])
        f.write(",\n") unless first
        first = false
        f.write(JSON.pretty_generate(serialized).split("\n").map { |l| "    #{l}" }.join("\n"))
        count += 1
        print "#{count} " if (count % 50).zero?

        next if all_mode
        next unless count >= limit

        puts "\nReached limit of #{limit}. Pass --all to export everything."
        break
      end

    f.write("\n  ],\n  \"count\": #{count}\n}\n")
  end

  puts "Exported #{count} collections to #{output_file}"
end
