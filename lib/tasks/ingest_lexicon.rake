# frozen_string_literal: true

IGNORE_LIST = %w(
  404Error.php
  contactform.php
  contactform1.php
  contactform2.php
  footera.php
  footerb.php
  footerbb.php
  footerf.php
  footerf-old.php
  footerm.php
  footergovrin.php
  footerk.php
  footerkishon.php
  footerm-old.php
  footermy.php
  footermz.php
  header.php
  header1.php
  header-beit-berl.php
  header-heksherim1.php
  header-heksherim.php
  header-yellin.php
  header2.php
  header77.php
  headera.php
  headerb.php
  headerbb.php
  headerk.php
  headery.php
).freeze

desc 'ingest Galron Lexicon static files for further processing'
task :ingest_lexicon, [:dirname] => :environment do |_taskname, args|
  die 'run again with a lexicon dir name, e.g. rake ingest_lexicon[/home/galron/lexicon]' if args.dirname.nil?
  thedir = args.dirname
  die "no such directory #{thedir}" unless Dir.exist?(thedir)
  i = 0
  files = Dir.glob(thedir + '/*.php')
  @total = files.count
  @new = 0
  @unclassified = 0
  @changed = 0
  @outbuf = ''
  print "Reading #{@total} files... "
  @people = []
  @bibs = []
  @texts = []
  files.each do |fname|
    next if IGNORE_LIST.include?(fname[(fname.rindex('/') + 1)..])

    process_legacy_lexicon_entry(fname)
    i += 1
    print "\n...#{i} " if i % 20 == 0
  rescue ArgumentError => e
    puts "\n#{e} bad encoding in #{fname}. " \
         "Run\n\nrake badchar[#{thedir}/#{fname}]\n\n to find what doesn't convert well."
  end
  puts "\nPEOPLE: " + @people.sort.join('; ')
  puts "\nTEXTS: " + @texts.sort.join('; ')
  puts "\nBIBS: " + @bibs.sort.join('; ')
  puts "Errors:\n#{@outbuf}"
  puts "#{@new} new entries ingested; #{@unclassified} remain unclassified; #{@changed} have changes since ingestion!"
  puts "\ndone!"
end

def die(msg)
  puts msg
  exit
end

def validate_title(title, fname)
  if title.blank?
    @outbuf += "\nCan't find title in #{fname}!\n"
    '???'
  elsif !title.any_hebrew?
    @outbuf += "\nNo Hebrew in #{validation} from #{fname}!\n"
    title
  end
end

def process_legacy_lexicon_entry(fname)
  should_process = false
  filepart = fname[(fname.rindex('/') + 1)..]
  lf = LexFile.where(fname: filepart).first
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
  return unless should_process

  entrytype = case fname
              when /999.+\.php/
                'bib'
              when %r{/\d\d\d\d\d\.php}
                'person'
              when /0\d\d\d\d.?\d\d\d\.php/
                'text'
              else
                @outbuf += "\nWhat to make of #{fname}?\n"
                @unclassified += 1
                'unknown'
              end

  title = Lexicon::ExtractTitle.call(fname)
  title = validate_title(title, fname)
  if lf.nil?
    LexFile.create!(
      fname: filepart,
      full_path: fname,
      status: entrytype == 'unknown' ? :unclassified : :classified,
      title: title,
      entrytype: entrytype
    )
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
