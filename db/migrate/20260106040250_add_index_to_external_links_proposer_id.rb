# frozen_string_literal: true

# Add index on proposer_id to optimize queries for proposer track records
class AddIndexToExternalLinksProposerId < ActiveRecord::Migration[8.0]
  def change
    add_index :external_links, :proposer_id
  end
end
