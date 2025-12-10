# frozen_string_literal: true

class DropImpressions < ActiveRecord::Migration[6.1]
  def change
    execute <<~SQL
        insert into year_totals (item_type, item_id, year, total, event, created_at, updated_at)
        select impressionable_type, impressionable_id, year, total_cnt, event, current_timestamp(), current_timestamp() from     
            (
                select
                    impressionable_type, impressionable_id, year(updated_at) as year, count(*) as total_cnt, 'view' as event 
                from
                    impressions 
                group by
                    impressionable_id, impressionable_type, year(updated_at)
            ) t
        on duplicate key update
            total = total + t.total_cnt, updated_at = current_timestamp()
    SQL

    drop_table :impressions, if_exists: true

    # we also purge all existing data from ahoy_visits and ahoy_events table to start from the scratch
    execute "truncate table ahoy_events"
    execute "truncate table ahoy_visits"
  end
end
