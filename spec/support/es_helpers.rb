# frozen_string_literal: true

# Helpers for specs that import into Elasticsearch and then immediately query it.
#
# `Chewy.massacre` (used by `clean_tables` and by many specs' `after` hooks) deletes
# every index in the cluster. A spec that recreates an index via `.import` can then
# race ES's shard allocation and get a transient
# `no_shard_available_action_exception` on the very next query. Blocking until the
# index reports at least "yellow" health removes that race deterministically -- no
# sleeps involved.
module EsHelpers
  def import_and_await(index, records)
    index.import(records)
    Chewy.client.cluster.health(index: index.index_name, wait_for_status: 'yellow', timeout: '30s')
  end
end

RSpec.configure do |config|
  config.include EsHelpers
end
