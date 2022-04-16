desc "ingest Galron Lexicon static files for further processing"
task :ingest_lexicon, [:dirname] => :environment do |taskname, args|
  die "run again with a lexicon dir name, e.g. rake ingest_lexicon[/home/galron/lexicon]" if args.dirname.nil?
  thedir = args.dirname
  die "no such directory #{thedir}" unless Dir.exists?(thedir)
  i = 0
  files = Dir.glob(thedir+'/*.php')
  total = files.count
  print "Reading #{total} files... "
  @people = []
  @bibs = []
  @texts = []
  files.each{|fname|
    begin
      process_legaxy_lexicon_entry(fname)
      i += 1
      print "\n...#{i} " if i % 20 == 0
    rescue
      puts "\n#{$!} bad encoding. Run\n\nrake badchar[full_path_to_offending_file]\n\n to find what doesn't convert well."
    end
  }
  puts "PEOPLE: " + @people.sort.join("; ")
  puts "\nTEXTS: " + @texts.sort.join("; ")
  puts "\nBIBS: " + @bibs.sort.join("; ")
  puts "\ndone!"
end

def die(msg)
  puts msg
  exit
end

def process_legaxy_lexicon_entry(fname)
  buf = File.open(fname).read.gsub("\r\n","\n")
  entrytype = case fname
    when /999.+\.php/
      'bib'
    when /\/\d\d\d\d\d\.php/
      'person'
    when /0\d\d\d\d.?\d\d\d\.php/
      'text'
    else
      puts "What to make of #{fname}?"
      '?'
    end
  is_person = (buf =~ /על המחברת ויצירתה/) || (buf =~ /על המחבר ויצירתו/) || (buf =~ /ספריה:/) || (buf =~ /ספריו:/) || (buf =~ /\(\d\d\d+\)/) || (buf =~ /\(\d\d\d+.\d\d\d+\)/)
  unless buf =~ /<p align="center"><font size="4".*?>(.*?)<\//
    "\nCan't find title in #{fname}!"
  else
    case entrytype
    when 'bib'
      @bibs << $1
    when 'text'
      @texts << $1
    when 'person'
      @people << $1
    end
  end
  print entrytype[0]
  #Chewy.strategy(:atomic) {
  #}
end