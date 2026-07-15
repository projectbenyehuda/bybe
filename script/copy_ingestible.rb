#!/usr/bin/env ruby
# frozen_string_literal: true

# Copy a single Ingestible row from one database (e.g. staging) into another
# (e.g. production) by generating a reviewable INSERT statement.
#
# This does NOT touch the target DB. It connects only to the SOURCE database,
# reads one ingestibles row, and writes a .sql file you can review and then
# slurp into the target DB yourself:
#
#   mysql -u USER -p TARGET_DB < ingestible_<id>.sql
#
# The Ingestible is self-contained: all the real work lives in text columns
# (markdown, works_buffer, toc_buffer, textarea_cache, *_authorities JSON,
# metadata). IngestibleText is not a table, just a JSON wrapper over
# works_buffer, so there is nothing else to copy. The attached DOCX (Active
# Storage) is intentionally NOT copied.
#
# Foreign-key columns (user_id, volume_id, project_id, authorities, ...) are
# carried over verbatim on the assumption that the target DB shares the same
# IDs (staging is a recent clone of production). Verify the values printed to
# STDERR before importing.
#
# Usage:
#   ruby script/copy_ingestible.rb \
#     --host HOST --port 3306 --user USER --password PASS \
#     --database SOURCE_DB --id INGESTIBLE_ID[,ID2,...] [--output FILE.sql] \
#     [--keep-id] [--keep-lock]
#
# --id accepts a comma-separated list; one .sql file is written per id. The
# --output name only applies when a single id is given.
#
# All connection flags may instead be supplied via the standard MySQL env
# vars: MYSQL_HOST, MYSQL_TCP_PORT, MYSQL_USER, MYSQL_PWD, MYSQL_DATABASE.

require 'mysql2'
require 'optparse'

TABLE = 'ingestibles'
# Columns that would drag a stale editing lock into the target; nulled unless --keep-lock.
LOCK_COLUMNS = %w[locked_at locked_by_user_id].freeze
# FK-ish columns worth eyeballing before import.
FK_COLUMNS = %w[
  user_id last_editor_id locked_by_user_id volume_id project_id
  periodical_id tasks_project_id originating_task prospective_volume_id
].freeze

options = {
  host: ENV['MYSQL_HOST'],
  port: (ENV['MYSQL_TCP_PORT'] || 3306).to_i,
  username: ENV['MYSQL_USER'],
  password: ENV['MYSQL_PWD'],
  database: ENV['MYSQL_DATABASE'],
  ids: [],
  output: nil,
  keep_id: false,
  keep_lock: false
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby script/copy_ingestible.rb [options]'
  opts.on('--host HOST', 'Source DB host') { |v| options[:host] = v }
  opts.on('--port PORT', Integer, 'Source DB port (default 3306)') { |v| options[:port] = v }
  opts.on('--user USER', 'Source DB user') { |v| options[:username] = v }
  opts.on('--password PASS', 'Source DB password') { |v| options[:password] = v }
  opts.on('--database DB', 'Source DB name') { |v| options[:database] = v }
  opts.on('--id IDS', 'Ingestible id(s) to copy, comma-separated') do |v|
    options[:ids] = v.split(',').map do |s|
      Integer(s.strip)
    rescue ArgumentError
      warn "Invalid id: #{s.strip.inspect} (must be an integer)."
      exit 1
    end
  end
  opts.on('--output FILE', 'Output .sql file (single id only; default ingestible_<id>.sql)') { |v| options[:output] = v }
  opts.on('--keep-id', 'Preserve the original id column (default: omit, let target auto-assign)') { options[:keep_id] = true }
  opts.on('--keep-lock', 'Preserve locked_at/locked_by_user_id (default: null them out)') { options[:keep_lock] = true }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit
  end
end
parser.parse!

missing = []
missing << '--host'     if options[:host].to_s.empty?
missing << '--user'     if options[:username].to_s.empty?
missing << '--database' if options[:database].to_s.empty?
missing << '--id'       if options[:ids].empty?
unless missing.empty?
  warn "Missing required options: #{missing.join(', ')}\n\n"
  warn parser
  exit 1
end

if options[:output] && options[:ids].length > 1
  warn '--output is ignored when copying multiple ids; using ingestible_<id>.sql for each.'
  options[:output] = nil
end

client = Mysql2::Client.new(
  host: options[:host],
  port: options[:port],
  username: options[:username],
  password: options[:password],
  database: options[:database],
  encoding: 'utf8mb4'
)

def sql_literal(value, client)
  return 'NULL' if value.nil?

  "'#{client.escape(value.to_s)}'"
end

exit_code = 0

options[:ids].each do |id|
  # cast: false => every value comes back as a raw String (or nil for NULL).
  # That is exactly what we want for SQL generation: no timezone/type coercion,
  # just escape the bytes. Numeric strings ('5') are valid for INT columns too.
  result = client.query("SELECT * FROM #{TABLE} WHERE id = #{id}", cast: false, as: :hash)

  row = result.first
  if row.nil?
    warn "No #{TABLE} row found with id=#{id} in #{options[:database]}; skipping."
    exit_code = 1
    next
  end

  # `fields` preserves the DB column order, which keeps the output readable.
  columns = result.fields.dup

  unless options[:keep_id]
    columns.delete('id')
    row.delete('id')
  end

  unless options[:keep_lock]
    LOCK_COLUMNS.each { |c| row[c] = nil if row.key?(c) }
  end

  col_list = columns.map { |c| "`#{c}`" }.join(', ')
  val_list = columns.map { |c| sql_literal(row[c], client) }.join(', ')

  sql = +"-- Ingestible ##{id} copied from #{options[:database]}@#{options[:host]}\n"
  sql << "-- Generated #{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')} UTC by script/copy_ingestible.rb\n"
  sql << "-- id #{options[:keep_id] ? 'preserved' : 'omitted (target will auto-assign)'}; " \
         "lock #{options[:keep_lock] ? 'preserved' : 'cleared'}.\n"
  sql << "-- DOCX attachment NOT included. Verify FK values below exist in the target DB.\n"
  sql << "INSERT INTO `#{TABLE}` (#{col_list})\nVALUES (#{val_list});\n"

  outfile = options[:output] || "ingestible_#{id}.sql"
  File.write(outfile, sql)

  warn "Wrote #{outfile} (#{sql.bytesize} bytes)."
  warn '  Foreign-key / reference columns carried over (verify these exist in the target DB):'
  FK_COLUMNS.each do |c|
    next unless row.key?(c)

    val = row[c]
    # locked_by_user_id may have just been nulled above; reflect the emitted value.
    warn format('    %-24s = %s', c, val.nil? ? 'NULL' : val)
  end
  warn ''
end

client.close

warn "Import with:  mysql -u USER -p TARGET_DB < ingestible_<id>.sql"
exit exit_code
