# frozen_string_literal: true

# sort_title is derived from title by the SortedTitle concern, so leaving it at varchar(255) would
# keep any title over 255 characters unsaveable even after title itself was widened. Widen it to
# match title.
#
# utf8mb4 varchar(2048) is 8192 bytes, past InnoDB's 3072-byte key limit, so the index has to become
# a prefix index. 255 characters is exactly what it covered before this change. Nothing in the app
# does SQL `ORDER BY collections.sort_title` -- alphabetical browsing of collections runs through
# CollectionsIndex in Elasticsearch -- so losing ORDER BY support on this index costs nothing.
class DoubleCollectionsSortTitleLimit < ActiveRecord::Migration[8.0]
  # Rails/BulkChangeTable wants one `change_table ... bulk: true`, but these three statements are
  # order-dependent: the index has to be gone before the column is widened past the key limit, and
  # recreated with the prefix afterwards. Folding them into a single ALTER would make correctness
  # depend on how MySQL orders the clauses.
  # rubocop:disable Rails/BulkChangeTable
  def up
    remove_index :collections, name: 'index_collections_on_sort_title'
    change_column :collections, :sort_title, :string, limit: 2048
    add_index :collections, :sort_title, name: 'index_collections_on_sort_title', length: 255
  end

  def down
    remove_index :collections, name: 'index_collections_on_sort_title'
    change_column :collections, :sort_title, :string, limit: 255
    add_index :collections, :sort_title, name: 'index_collections_on_sort_title'
  end
  # rubocop:enable Rails/BulkChangeTable
end
