# frozen_string_literal: true

# Adds the target of a soft-deleted (deprecated) Manifestation's redirect.
class AddSoftRedirectToManifestations < ActiveRecord::Migration[8.1]
  def change
    change_table :manifestations, bulk: true do |t|
      t.integer :soft_redirect
      t.index :soft_redirect
    end
  end
end
