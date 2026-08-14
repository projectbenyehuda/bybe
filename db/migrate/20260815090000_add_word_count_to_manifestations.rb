# frozen_string_literal: true

# Caches each Manifestation's word count in a column. It used to be counted from the markdown on
# every call, which is fine for one work but not for the works lists that now show it for a whole
# screenful at a time.
class AddWordCountToManifestations < ActiveRecord::Migration[8.0]
  BATCH_SIZE = 500

  def up
    add_column :manifestations, :word_count, :integer unless column_exists?(:manifestations, :word_count)

    Manifestation.reset_column_information
    # Backfilled without callbacks: the value is purely derived, so filling it in should disturb
    # neither updated_at (caches downstream are keyed on it) nor the Elasticsearch index. Counting
    # has to happen in Ruby (no SQL equivalent of String#split), but the writes go one statement
    # per batch: the corpus is tens of thousands of works, and a statement each would take hours.
    # suppress_messages: each statement names every id in the batch, which is unreadable in a log.
    suppress_messages do
      Manifestation.where(word_count: nil).select(:id, :markdown).find_in_batches(batch_size: BATCH_SIZE) do |batch|
        counts = batch.to_h { |m| [m.id, m.markdown.to_s.split.length] }
        whens = counts.map { |id, count| "WHEN #{id} THEN #{count}" }.join(' ')
        execute("UPDATE manifestations SET word_count = CASE id #{whens} END WHERE id IN (#{counts.keys.join(',')})")
      end
    end
  end

  def down
    remove_column :manifestations, :word_count
  end
end
