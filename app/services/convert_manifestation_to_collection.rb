# frozen_string_literal: true

# Converts a Manifestation that was wrongly ingested as a single text into a Collection of texts, one per
# top-level ('## ') heading in its markdown.
#
# - The original Manifestation (and its Expression and Work) keep their ids, so the text's URL stays valid,
#   but become the *first* text: its title and markdown.
# - Every further section becomes a new Manifestation, with a new Expression and Work, all copying the
#   original records' metadata and involved authorities, and taking the section's heading as their title.
# - Within each text the heading that became its title is removed and all deeper headings are promoted by
#   one level ('###' becomes '##', and so on).
# - Footnote bodies are handed to the text that references them, since they otherwise all sit at the end
#   of the last section. A footnote marker on a heading line is moved to the top of that text's body.
# - Any text preceding the first heading is kept as a markdown placeholder at the top of the Collection.
# - The new Collection takes the original title, and the original's involved authorities. It takes the
#   original Manifestation's place in any collection that contained it, except for an authority's
#   'uncollected works' collection, which by definition no longer applies.
#
# Returns { success: true, collection: Collection } or { success: false, error: '...' }.
class ConvertManifestationToCollection < ApplicationService
  HEADING = /\A##(?!#)(.*)/
  FOOTNOTE_DEFINITION = /\A\[\^([^\]]+)\]:/
  FOOTNOTE_REFERENCE = /\[\^([^\]]+)\](?!:)/

  def call(manifestation, collection_type)
    @manifestation = manifestation
    @expression = manifestation.expression
    @work = @expression.work

    return failure(I18n.t(:convert_to_collection_bad_type)) unless allowed_type?(collection_type)

    preamble, sections = split_markdown(manifestation.markdown.to_s)
    return failure(I18n.t(:convert_to_collection_too_few_headings)) if sections.size < 2
    return failure(I18n.t(:convert_to_collection_blank_heading)) if sections.any? { |s| s[:title].blank? }

    collection = nil
    ActiveRecord::Base.transaction do
      collection = create_collection(collection_type)
      replace_in_parent_collections(collection)
      seqno = 0
      if preamble.present?
        CollectionItem.create!(collection: collection, seqno: seqno += 1, markdown: preamble)
      end
      update_original(sections.first)
      CollectionItem.create!(collection: collection, seqno: seqno += 1, item: @manifestation)
      sections.drop(1).each do |section|
        CollectionItem.create!(collection: collection, seqno: seqno += 1, item: clone_manifestation(section))
      end
    end
    { success: true, collection: collection }
  rescue StandardError => e
    Rails.logger.error("ConvertManifestationToCollection failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    failure(e.message)
  end

  private

  def failure(error)
    { success: false, error: error }
  end

  def allowed_type?(collection_type)
    Collection.collection_types.key?(collection_type.to_s) && Collection::SYSTEM_TYPES.exclude?(collection_type.to_s)
  end

  # Returns [preamble, sections], where preamble is the (possibly blank) markdown preceding the first
  # heading and each section is { title:, markdown: }, with footnote bodies redistributed to the part that
  # references them.
  def split_markdown(markdown)
    parts = [{ title: nil, title_refs: [], lines: [] }]
    markdown.each_line do |line|
      match = HEADING.match(line.chomp)
      if match
        heading = match[1]
        parts << { title: clean_title(heading), title_refs: heading.scan(FOOTNOTE_REFERENCE).flatten, lines: [] }
      else
        parts.last[:lines] << promote_heading(line)
      end
    end

    definitions = parts.each_with_index.flat_map { |part, i| extract_definitions(part, i) }
    definitions.each do |definition|
      owner = parts.index { |part| references?(part, definition[:label]) } || definition[:found_in]
      parts[owner][:definitions] = (parts[owner][:definitions] || []) << definition[:text]
    end

    texts = parts.map { |part| assemble(part) }
    [texts.first, parts.drop(1).zip(texts.drop(1)).map { |part, text| { title: part[:title], markdown: text } }]
  end

  def clean_title(heading)
    heading.gsub(FOOTNOTE_REFERENCE, '').gsub(/\\([\[\]*_{}()#+\-.!'"<>])/, '\1').strip
  end

  # The heading that became a text's title is gone, so what was a sub-heading of it moves up a level.
  def promote_heading(line)
    line.start_with?('###') ? line[1..] : line
  end

  # Removes footnote bodies from the part's lines, returning them. A body runs from its '[^label]:' line up
  # to the next body or the end of the part -- the same rule Ingestible#relocate_footnotes follows.
  def extract_definitions(part, index)
    start = part[:lines].index { |line| FOOTNOTE_DEFINITION.match?(line) }
    return [] if start.nil?

    block = part[:lines].slice!(start..)
    block.slice_before { |line| FOOTNOTE_DEFINITION.match?(line) }.map do |lines|
      { label: FOOTNOTE_DEFINITION.match(lines.first)[1], text: lines.join.strip, found_in: index }
    end
  end

  def references?(part, label)
    part[:title_refs].include?(label) || part[:lines].join.scan(FOOTNOTE_REFERENCE).flatten.include?(label)
  end

  def assemble(part)
    title_markers = part[:title_refs].map { |label| "[^#{label}]" }.join
    body = part[:lines].join.strip
    body = "#{title_markers}\n#{body}" if title_markers.present?
    return body if part[:definitions].blank?

    "#{body}\n\n#{part[:definitions].join("\n\n")}\n"
  end

  def create_collection(collection_type)
    collection = Collection.create!(title: @manifestation.title, collection_type: collection_type)
    (@work.involved_authorities.to_a + @expression.involved_authorities.to_a)
      .map { |ia| [ia.authority_id, ia.role] }.uniq
      .each { |authority_id, role| collection.involved_authorities.create!(authority_id: authority_id, role: role) }
    collection
  end

  # Queried directly rather than through @manifestation.collection_items, which may be stale.
  def replace_in_parent_collections(collection)
    CollectionItem.where(item: @manifestation).includes(:collection).find_each do |ci|
      ci.collection.uncollected? ? ci.destroy! : ci.update!(item: collection)
    end
  end

  def update_original(section)
    @work.update!(title: section[:title])
    @expression.update!(title: section[:title])
    # the old title's alternate forms belong to the collection now
    @manifestation.alternate_titles = nil
    @manifestation.title = section[:title]
    @manifestation.markdown = section[:markdown]
    @manifestation.recalc_heading_lines
    @manifestation.save!
  end

  def clone_manifestation(section)
    work = clone_with_authorities(@work, title: section[:title])
    expression = clone_with_authorities(@expression, title: section[:title], work: work)
    manifestation = @manifestation.dup
    manifestation.assign_attributes(expression: expression, title: section[:title], markdown: section[:markdown],
                                    alternate_titles: nil, sort_title: nil, impressions_count: 0)
    manifestation.recalc_heading_lines
    manifestation.recalc_word_count
    manifestation.save!
    manifestation
  end

  def clone_with_authorities(record, attributes)
    copy = record.dup
    copy.assign_attributes(attributes)
    copy.save!
    record.involved_authorities.each do |ia|
      copy.involved_authorities.create!(authority_id: ia.authority_id, role: ia.role)
    end
    copy
  end
end
