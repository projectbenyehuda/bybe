# frozen_string_literal: true

app_dir = File.expand_path('..', __dir__)
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
      config.ram           = 7096 # mb
      config.frequency     = 60    # seconds
      config.percent_usage = 0.98
      config.rolling_restart_frequency = 1 * 3600 # 12 hours in seconds, or 12.hours if using Rails
      #config.reaper_status_logs = true # setting this to false will not log lines like:
      # PumaWorkerKiller: Consuming 54.34765625 mb with master and 2 workers.

      # config.pre_term = -> (worker) { puts "Worker #{worker.inspect} being killed" }
      # config.rolling_pre_term = -> (worker) { puts "Worker #{worker.inspect} being killed by rolling restart" }
    end
    PumaWorkerKiller.start
  end

else
  workers 3
  environment 'development'
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments.
plugin :solid_queue if ENV['SOLID_QUEUE_IN_PUMA']

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV['PIDFILE'] if ENV['PIDFILE']
