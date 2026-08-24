# frozen_string_literal: true

# Adds the target of a soft-deleted (deprecated) Manifestation's redirect.
class AddSoftRedirectToManifestations < ActiveRecord::Migration[8.1]
  # Rails/BulkChangeTable wants these combined into one `change_table ... bulk: true`, which on this
  # table is a bad trade: bulk forces the COPY algorithm and a full rebuild of `manifestations`,
  # measured here at 507 seconds against 2.2 for the two statements below, which MySQL does INSTANT
  # and INPLACE. The table only grows, so keep the fast form.
  # rubocop:disable Rails/BulkChangeTable
  def change
    add_column :manifestations, :soft_redirect, :integer
    add_index :manifestations, :soft_redirect
  end
  # rubocop:enable Rails/BulkChangeTable
end
