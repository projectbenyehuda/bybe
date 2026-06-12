require 'sqlite3'

namespace :dict do
  desc "Import dictionary definitions from a sqlite DB for a given manifestation ID"
  task :import, [:db_file, :mani_id] => :environment do |taskname, args|
    unless args.db_file.nil? or args.mani_id.nil?
      db = SQLite3::Database.new args.db_file
      db.results_as_hash = true
      $mani_id = args.mani_id.to_i
      i = 1
      updated = 0
      created = 0
      $links_created = 0
      @last_sort_defhead = ''
      dict_count = db.execute("SELECT COUNT(*) FROM entries")[0]['COUNT(*)']
      puts "Processing #{dict_count} dictionary entries"
      Chewy.strategy(:atomic) do
        db.execute("SELECT foreign_id, ordinal, defhead, deftext FROM entries") do |row|
          source_id = row['foreign_id'].to_i
          ordinal = row['ordinal'].to_i
          sort_defhead = get_sort_defhead(row['defhead'])
          deftext = row['deftext']
          des = DictionaryEntry.where(manifestation_id: $mani_id, source_def_id: source_id)
          if des.empty?
            @de = DictionaryEntry.new(manifestation_id: $mani_id, source_def_id: source_id, sequential_number: ordinal, defhead: row['defhead'], deftext: deftext, sort_defhead: sort_defhead)
            created += 1
          else # merge into existing entry
            @de = des.first
            if @de.defhead != row['defhead'] || @de.deftext != deftext || @de.sort_defhead != sort_defhead
              @de.update(defhead: row['defhead'], deftext: deftext, sort_defhead: sort_defhead)
              updated += 1
            end
          end
          @de.save!
          
          db.execute("SELECT alias FROM aliases WHERE foreign_id = ?", source_id) do |alrow|
            if DictionaryAlias.where(dictionary_entry_id: @de.id, alias: alrow['alias']).empty?
              al = DictionaryAlias.new(dictionary_entry_id: @de.id, alias: alrow['alias'])
              al.save!
            end
          end
          i += 1
          print "#{i}... " if i % 200 == 0
        end
        print "updating Elastic... "
      end
      puts "done!"
      i = 0
      print "linking entries... "
      Chewy.strategy(:atomic) do
        DictionaryEntry.where(manifestation_id: $mani_id).each do |de|
          de.deftext = correct_internal_links(de.id, de.deftext)
          de.save!
          i += 1
          print "#{i}... " if i % 200 == 0
        end
        print "updating Elastic... "
      end
      puts "done!\nCreated #{created} entries and updated #{updated}.  #{$links_created} links created."
    else
      puts "please specify the path and filename of the SQLite database with the dictionary entries, and the manifestation ID of the dictionary to import to.\ne.g. rake dict:import[/home/xyzzy/dict.db,1234]"
    end
  end
end
private
def get_sort_defhead(dh)
  return @last_sort_defhead if dh.nil?
  ret = dh
  ret = $' if dh =~ /^.\. /
  ret = ret.strip_nikkud
  @last_sort_defhead = ret
  return ret
end

def create_or_update_dict_link(from_id, to_id)
  des = DictionaryLink.where(from_entry_id: from_id, to_entry_id: to_id)
  if des.empty?
    dl = DictionaryLink.new(from_entry_id: from_id, to_entry_id: to_id)
    dl.save!
    $links_created += 1
  end
end

def correct_internal_links(from_id, buf)
  buf.gsub(/https:\/\/ebydict\.benyehuda\.org\/definition\/view\/(\d+)/) {|match|
    recs = DictionaryEntry.where(manifestation_id: $mani_id, source_def_id: $1)
    create_or_update_dict_link(from_id, recs[0].id) unless recs.empty?
    recs.empty? ? match : "/dict/#{$mani_id}/#{recs[0].id}"
  }
end