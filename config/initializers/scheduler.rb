require 'rufus-scheduler'

scheduler = Rufus::Scheduler::singleton

# jobs go here

# daily stats
scheduler.every '24h' do
  puts "calculating popular authors..."
  Authority.recalc_popular
  #puts "calculating recommendation counts..."
  #Person.recalc_recommendation_counts
end
scheduler.every '36h' do
  Manifestation.get_popular_works
end
scheduler.every '2h' do
  puts "expiring assigned crowdsourcing tasks"
  CrowdController.expire_assigned_tasks
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
  NotificationDigestJob.perform_async('daily')
end

scheduler.every '7d' do
  puts "sending weekly notification digests"
  NotificationDigestJob.perform_async('weekly')
end