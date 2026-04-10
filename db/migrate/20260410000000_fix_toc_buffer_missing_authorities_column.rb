# frozen_string_literal: true

# Before October 2024 the toc_buffer format was:
#   yes/no || title || genre || lang [|| ip]
#
# The authorities column was then inserted at index 2, making the current format:
#   yes/no || title || authorities_json || genre || lang [|| ip]
#
# This migration retrofits existing rows that still use the old layout by
# inserting an empty authorities field at position 2.
class FixTocBufferMissingAuthoritiesColumn < ActiveRecord::Migration[8.0]
  def up
    Ingestible.where.not(toc_buffer: [nil, '']).find_each do |ingestible|
      lines = ingestible.toc_buffer.lines.map(&:strip).reject(&:empty?)
      needs_update = false

      new_lines = lines.map do |line|
        parts = line.split('||').map(&:strip)
        next line if parts.length < 3 || parts[2].blank?

        begin
          JSON.parse(parts[2])
          line # Already valid JSON – nothing to do
        rescue JSON::ParserError
          needs_update = true

          if parts.length <= 5
            # Old format:
            #   yes/no || title || genre || lang [|| ip]
            # Insert empty authorities at index 2.
            ([parts[0], parts[1], ''] + parts[2..]).join(' || ')
          else
            # Already in new format, but authorities JSON is malformed.
            # Normalize authorities in place without shifting genre/lang/ip.
            ([parts[0], parts[1], '[]'] + parts[3..]).join(' || ')
          end
        end
      end

      ingestible.update_columns(toc_buffer: new_lines.join("\n")) if needs_update
    end
  end

  def down
    # Not reversible – we can't tell which empty authorities slots were added
    # by this migration versus already being present in the new format.
    raise ActiveRecord::IrreversibleMigration
  end
end
