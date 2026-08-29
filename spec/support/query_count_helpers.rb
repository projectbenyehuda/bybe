# frozen_string_literal: true

# Helper for specs guarding against N+1 queries: runs the block and returns how many
# SQL queries it issued. Cached queries and schema introspection are not counted, since
# neither reaches the database on a warm connection.
module QueryCountHelpers
  def count_queries(&)
    count_queries_matching(//, &)
  end

  # As count_queries, but counting only the queries whose SQL matches the given pattern, e.g. to
  # guard a single table against N+1 without being sensitive to unrelated queries on the page.
  def count_queries_matching(pattern, &)
    count = 0
    counter = lambda do |*, payload|
      next if payload[:cached] || payload[:name] == 'SCHEMA'

      count += 1 if payload[:sql].match?(pattern)
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCountHelpers
end
