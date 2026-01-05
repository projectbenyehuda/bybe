# frozen_string_literal: true

class AddProposerToExternalLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :external_links, :proposer_id, :integer
    add_column :external_links, :proposer_email, :string
  end
end
