require 'rufus-scheduler'

scheduler = Rufus::Scheduler::singleton

# jobs go here

# daily stats
# scheduler.every '24h' do
  # puts "calculating recommendation counts..."
  # Person.recalc_recommendation_counts
# end
scheduler.every '2h' do
  ExpireCrowdsourcingTasksJob.perform_later
end

# slow maintenance reports
scheduler.every '7d' do
  puts "generating list of works with suspected typos"
  Manifestation.update_suspected_typos_list
  puts "generating list of bib publications that may already be in the system"
  Publication.update_publications_that_may_be_done_list
end

# Email digest notifications
scheduler.every '24h' do
  puts "sending daily notification digests"
  NotificationDigestJob.perform_later('daily')
end

scheduler.every '7d' do
  puts "sending weekly notification digests"
  NotificationDigestJob.perform_later('weekly')
end

scheduler.every '7d' do
  PurgeExpiredSavedSelections.perform_later
end

scheduler.cron '0 2 * * 3 Asia/Jerusalem' do
  Rails.logger.info 'Trimming db sessions'
  # NOTE: this will also trim BaseUsers table and cleanup Ahoy Events
  system('bin/rake db:sessions:trim')
end
