# frozen_string_literal: true

# Helper for specs guarding against N+1 queries: runs the block and returns how many
# SQL queries it issued. Cached queries and schema introspection are not counted, since
# neither reaches the database on a warm connection.
module QueryCountHelpers
  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCountHelpers
end
