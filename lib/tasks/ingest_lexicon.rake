desc "ingest Galron Lexicon static files for further processing"
task :ingest_lexicon, [:dirname] => :environment do |taskname, args|
  die "run again with a lexicon dir name, e.g. rake ingest_lexicon[/home/galron/lexicon]" if args.dirname.nil?
  thedir = args.dirname
  die "no such directory #{thedir}" unless Dir.exists?(thedir)
  i = 0
  files = Dir.glob(thedir+'/*.php')
  @total = files.count
  @new = 0
  @unclassified = 0
  @changed = 0
  @outbuf = ""
  print "Reading #{@total} files... "
  @people = []
  @bibs = []
  @texts = []
  files.each{|fname|
    begin
      process_legaxy_lexicon_entry(fname)
      i += 1
      print "\n...#{i} " if i % 20 == 0
    rescue
      puts "\n#{$!} bad encoding in #{fname}. Run\n\nrake badchar[#{thedir}/#{fname}]\n\n to find what doesn't convert well."
    end
  }
  puts "\nPEOPLE: " + @people.sort.join("; ")
  puts "\nTEXTS: " + @texts.sort.join("; ")
  puts "\nBIBS: " + @bibs.sort.join("; ")
  puts "Errors:\n#{@outbuf}"
  puts "#{@new} new entries ingested; #{@unclassified} remain unclassified; #{@changed} have changes since ingestion!"
  puts "\ndone!"
end

def die(msg)
  puts msg
  exit
end

def validate_title(title, fname)
  validation = title.strip.gsub("&nbsp;",'').gsub('בהכנה','')
  unless validation.any_hebrew?
    @outbuf += "\nNo Hebrew in #{validation} from #{fname}!\n"
  end
  return validation
end

def process_legaxy_lexicon_entry(fname)
  filepart = fname[fname.rindex('/')..-1]
  lf = LexFile.where(fname: filepart).first
  should_process = false
  if lf.nil?
    should_process = true
    @outbuf += "\nNEW FILE: #{fname}\n"
  else
    should_process = true if lf.status_unclassified?
    if lf.updated_at < File.mtime(fname)
      should_process = true
      lf.status_changed_after_ingestion!
      @changed += 1
    end
  end
  if should_process
    buf = File.open(fname).read.gsub("\r\n","\n")
    buf = buf[0..3000] if buf.length > 3000 # the entry name seems to always occur a little after 2000 chars
    entrytype = case fname
      when /999.+\.php/
        'bib'
      when /\/\d\d\d\d\d\.php/
        'person'
      when /0\d\d\d\d.?\d\d\d\.php/
        'text'
      else
        @outbuf += "\nWhat to make of #{fname}?\n"
        @unclassified += 1
        'unknown'
      end
    is_person = (buf =~ /על המחברת ויצירתה/) || (buf =~ /על המחבר ויצירתו/) || (buf =~ /ספריה:/) || (buf =~ /ספריו:/) || (buf =~ /\(\d\d\d+\)/) || (buf =~ /\(\d\d\d+.\d\d\d+\)/)
    title = buf.gsub("\n",' ').scan(/<p align="center"><font size="[4|5]".*?>(.*?)<\//).join(' ')
    if title.nil? || title.strip.empty? 
      title = '???'
      @outbuf += "\nCan't find title in #{fname}!\n"
    end
    title = validate_title(title, fname)
    if lf.nil?
      lf = LexFile.create!(fname: filepart, status: entrytype == 'unknown' ? :unclassified : :classified, title: title, entrytype: entrytype)
      @new += 1
    else
      lf.update!(entrytype: entrytype)
    end
    case entrytype
    when 'bib'
      @bibs << title
    when 'text'
      @texts << title
    when 'person'
      @people << title
    end
    print entrytype[0]
  end
end