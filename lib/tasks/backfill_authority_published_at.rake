# frozen_string_literal: true

# Authority#published_at backs the 'upload date' sort on /authors, via
# AuthoritiesIndex#pby_publication_date. It used to be written only inside Authority#publish!, and
# the authors#update call site guarded on status_changed?, which Rails resets to false as soon as
# the update succeeds -- so authorities published from the edit form never got one. Elasticsearch
# omits a null field and sorts missing values last, so those authorities were invisible at the top
# of 'newest first'.
#
# The stamping itself is fixed in the model, but roughly 1,150 authorities are left carrying a NULL
# and need a historical date. PaperTrail cannot supply it: has_paper_trail was added to Authority
# long after most of these were published, so only a handful have any version row at all and none
# have object_changes populated. The best available proxy is the date the authority's first work
# went live -- publish! back-dates works' created_at to publication time, so for authorities
# published that way it is near exact. Authorities with no published works fall back to their own
# created_at.
#
# Only rows where published_at IS NULL are touched, so the task is safe to re-run.
desc 'Backfill Authority#published_at for published authorities that never got one'
task backfill_authority_published_at: :environment do
  scope = Authority.published.where(published_at: nil)
  total = scope.count
  puts "Found #{total} published authorities with no published_at."

  if total.zero?
    puts 'Nothing to do.'
    next
  end

  from_works = 0
  from_created_at = 0
  skipped = 0

  scope.find_each do |authority|
    first_work_at = authority.published_manifestations.minimum(:created_at)
    stamp = first_work_at || authority.created_at

    if stamp.nil?
      # No works and no creation date: nothing defensible to write.
      puts "  SKIP #{authority.id} (#{authority.name}): no work dates and no created_at"
      skipped += 1
      next
    end

    # update_column deliberately: this is a mechanical repair of a derived value, so it should not
    # bump updated_at, fire the publishing callbacks, or emit a PaperTrail version per row.
    authority.update_column(:published_at, stamp)

    if first_work_at.nil?
      from_created_at += 1
    else
      from_works += 1
    end
  end

  puts "Backfilled #{from_works + from_created_at} authorities " \
       "(#{from_works} from earliest published work, #{from_created_at} from authority created_at)."
  puts "Skipped #{skipped}." if skipped.positive?

  puts 'Reindexing AuthoritiesIndex so the upload-date sort picks up the new dates...'
  AuthoritiesIndex.import
  puts 'Done.'
end
