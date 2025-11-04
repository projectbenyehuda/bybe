app_dir = File.expand_path("../..", __FILE__)
shared_dir = "#{app_dir}"
rackup(File.expand_path('../config.ru', __dir__))
if ENV['RACK_ENV'] == 'production'
  require 'puma/daemon'
  environment 'production'
  workers Integer(ENV['WEB_CONCURRENCY'] || 8)
  daemonize
  bind "unix://#{shared_dir}/tmp/sockets/puma.sock"
  stdout_redirect "#{shared_dir}/log/puma.stdout.log", "#{shared_dir}/log/puma.stderr.log", true
  before_fork do
    require 'puma_worker_killer'
    PumaWorkerKiller.config do |config|
      config.ram           = 6096 # mb
      config.frequency     = 60    # seconds
      config.percent_usage = 0.98
      #config.rolling_restart_frequency = 12 * 3600 # 12 hours in seconds, or 12.hours if using Rails
      #config.reaper_status_logs = true # setting this to false will not log lines like:
      # PumaWorkerKiller: Consuming 54.34765625 mb with master and 2 workers.
  
      #config.pre_term = -> (worker) { puts "Worker #{worker.inspect} being killed" }
      #config.rolling_pre_term = -> (worker) { puts "Worker #{worker.inspect} being killed by rolling restart" }
    end
    PumaWorkerKiller.start
  end
  
else
  workers 0
  environment 'development'
end

threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 3)
threads 1, threads_count

preload_app!

# port        ENV['PORT']     || 3000
pidfile "#{shared_dir}/tmp/pids/puma.pid"

