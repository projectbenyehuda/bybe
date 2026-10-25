# frozen_string_literal: true

require 'csv'

# Authority#volumes inner-joins involved_authorities, so a volume collection with no involved_authority
# of its own is invisible to it (lexicon collection dropdown, verification auto-matcher, ...). This
# task gives such a volume an :author row when all its manifestations share one single author, and
# writes the rest to a CSV for an editor to triage (some are probably anthologies mistyped as
# `volume`, where adding an author would be wrong). Idempotent: assigned volumes drop out of the
# candidate set. See bead by-6td.
#
#   rake backfill_volume_authorities                    # DRY_RUN=1 to change nothing
#   rake backfill_volume_authorities REPORT=/tmp/x.csv  # where to write the review CSV
desc 'Assign the shared author to authority-less volumes; write the rest to a CSV for review'
task backfill_volume_authorities: :environment do
  dry_run = ENV['DRY_RUN'].present?
  report_path = ENV.fetch('REPORT', Rails.root.join('tmp/volumes_needing_authority_review.csv').to_s)

  service = BackfillVolumeAuthorities.call(dry_run: dry_run)

  puts "#{dry_run ? 'WOULD ASSIGN' : 'Assigned'} an author to #{service.assigned.size} volumes:"
  service.assigned.each do |r|
    puts "  ##{r.collection.id} #{r.collection.title} -> #{r.authorities.first.name} (#{r.item_count} items)"
  end

  CSV.open(report_path, 'w', encoding: 'UTF-8') do |csv|
    csv << %w(collection_id title item_count reason authority_ids authority_names url)
    service.needs_review.each do |r|
      csv << [r.collection.id, r.collection.title, r.item_count, r.reason,
              r.authorities.map(&:id).join(';'), r.authorities.map(&:name).join(';'),
              "https://benyehuda.org/collections/#{r.collection.id}"]
    end
  end
  puts "#{service.needs_review.size} volumes need review; CSV written to #{report_path}"
end
