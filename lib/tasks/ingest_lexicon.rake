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
    short_fname = fname[(fname.rindex('/') + 1)..]
    next if IGNORE_LIST.include?(short_fname)

    # At the first stage only process files where name is numeric.
    # We exclude non-standard files like appendixes, see https://github.com/projectbenyehuda/bybe/issues/1049
    next unless short_fname =~ /\A\d+\.php\z/

    Chewy.strategy(:atomic) do
      process_legacy_lexicon_entry(fname)
    end
    i += 1
    print "\n...#{i} " if i % 20 == 0
  rescue ArgumentError => e
    puts "\n#{e} unexpected error in #{fname}. "
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
  if title.blank? || title == '־'
    @outbuf += "\nCan't find title in #{fname}!\n"
    title = '???'
  elsif !title.any_hebrew?
    @outbuf += "\nNo Hebrew in #{title} from #{fname}!\n"
  end

  title
end

def process_legacy_lexicon_entry(fname)
  should_process = false
  filepart = fname[(fname.rindex('/') + 1)..]
  lf = LexFile.find_by(fname: filepart)
  if lf.nil?
    should_process = true
    @outbuf += "\nNEW FILE: #{fname}\n"
  else
    should_process = true if lf.status_unclassified?
    if lf.updated_at < File.mtime(fname)
      should_process = true
      lex_item = lf.lex_entry&.lex_item
      if lex_item.present?
        lex_item.destroy!
        lf.lex_entry.lex_item = nil
        lf.lex_entry.status_raw!
      end
      @changed += 1
    end
  end
  return unless should_process

  entrytype = LexFile.entrytype_from_filename(filepart)

  if entrytype == 'unknown'
    @outbuf += "\nWhat to make of #{fname}?\n"
    @unclassified += 1
  end

  title = Lexicon::ExtractTitle.call(fname)
  title = validate_title(title, fname)

  status = entrytype == 'unknown' ? :unclassified : :classified

  # Main entries (shown in /lex) have a filename of precisely five digits, e.g.
  # 00001.php. Other numeric filenames (e.g. 02645001.php) are secondary entries,
  # reachable only via internal links from another entry.
  is_main = filepart.match?(/\A\d{5}\.php\z/)

  if lf.nil?
    lex_entry = LexEntry.create!(
      title: title,
      status: :raw,
      main: is_main
    )

    LexFile.create!(
      fname: filepart,
      full_path: fname,
      status: status,
      entrytype: entrytype,
      lex_entry: lex_entry
    )

    @new += 1
  else
    lf.update!(entrytype: entrytype, status: status)
    lex_entry = lf.lex_entry
    lex_entry.update!(main: is_main) if lex_entry.main != is_main
    # Refresh the title whenever the source file changed. This must not be tied to the
    # presence of a lex_item: entries still awaiting migration have no lex_item, and used
    # to keep their originally ingested title forever.
    lex_entry.update!(title: title) if lex_entry.title != title
    lex_item = lex_entry.lex_item
    # destroying item to be recreated during ingestion
    if lex_item.present?
      lex_entry.lex_item = nil
      lex_entry.status_raw!
      lex_item.destroy!
    end
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

# UTF-8 Hebrew decoded as ISO-8859-1 leaves U+00D7 (×) followed by a Latin-1 supplement or
# C1 character. No genuine lexicon title looks like that.
MOJIBAKE_TITLE_PATTERN = /\u00D7[\u0080-\u00FF]/

desc 'repair Lexicon entry titles mangled by the ISO-8859-1 parsing fallback'
task fix_lexicon_titles: :environment do
  found = 0
  fixed = 0
  missing = []
  still_mangled = []

  Chewy.strategy(:atomic) do
    # `LIKE` is only a cheap pre-filter here; the regex below decides.
    LexEntry.includes(:lex_file).where('title LIKE ?', '%×%').find_each do |entry|
      next unless entry.title.match?(MOJIBAKE_TITLE_PATTERN)

      found += 1
      path = entry.lex_file&.full_path
      if path.blank? || !File.exist?(path)
        missing << entry.id
        next
      end

      title = Lexicon::ExtractTitle.call(path)
      if title.blank? || title.match?(MOJIBAKE_TITLE_PATTERN)
        still_mangled << entry.id
        next
      end

      puts "#{entry.id}: #{entry.title.inspect} -> #{title}"
      entry.update!(title: title)
      fixed += 1
    end
  end

  puts "#{found} mangled titles found; #{fixed} repaired"
  puts "No readable source file for entry ids: #{missing.join(', ')}" if missing.any?
  puts "Source file still yields a mangled title for entry ids: #{still_mangled.join(', ')}" if still_mangled.any?
end

desc 'flag already-migrated person entries whose bibliography section produced no citations'
task flag_unmigrated_citations: :environment do
  flagged = []
  missing = []
  failed = []

  # Only entries that migrated to a LexPerson with no citations at all can be affected; every
  # other person entry is left untouched, so this reads a few dozen files rather than the corpus.
  LexPerson.left_joins(:citations).where(lex_citations: { id: nil })
           .includes(entry: :lex_file).find_each do |lex_person|
    lex_file = lex_person.entry&.lex_file
    next if lex_file.nil? || !lex_file.entrytype_person?

    path = lex_file.full_path
    if path.blank? || !File.exist?(path)
      missing << lex_file.fname
      next
    end

    content = Lexicon::HtmlUtils.parse_file(path).to_html
    flagged << lex_file.fname if Lexicon::FlagUnmigratedCitations.call(lex_file, lex_person, content)
  # One unreadable or undecodable file must not cut the sweep short and hide every candidate
  # that comes after it.
  rescue StandardError => e
    failed << "#{lex_file.fname} (#{e.message})"
  end

  puts "#{flagged.size} entries flagged: #{flagged.sort.join(', ')}"
  puts "No readable source file for: #{missing.sort.join(', ')}" if missing.any?
  puts "Could not be checked: #{failed.sort.join(', ')}" if failed.any?
end

desc 'recheck lexicon links already recorded as broken, so bot-challenged ones become unverifiable'
task recheck_broken_lexicon_links: :environment do
  checker = Lexicon::CheckExternalLinks.new

  # Only records with an HTTP status >= 400 are candidates: a bot challenge always comes back as a
  # real response (hence a status), so a nil status means an unreachable host, which re-checking
  # would only spend a timeout on. Records already flagged unverifiable need no second look.
  links = LexLink.where(unverifiable: false).where(http_status: 400..)
  citations = LexCitation.where(link_unverifiable: false).where(link_http_status: 400..)

  # Tallied as we go rather than by counting the relations afterwards: rechecking moves rows out
  # of these scopes (a link that now answers 200, or one we have just flagged unverifiable), so a
  # trailing relation.count would re-run the query against the mutated rows and under-report.
  checked_links = 0
  checked_citations = 0
  reclassified = 0

  links.find_each do |link|
    result = checker.check_url(link.url)
    link.update_columns(http_status: result.status, unverifiable: result.unverifiable?, checked_at: Time.current)
    checked_links += 1
    next unless result.unverifiable?

    reclassified += 1
    puts "LexLink #{link.id}: #{link.url} -> unverifiable (HTTP #{result.status})"
  end

  citations.find_each do |citation|
    result = checker.check_url(citation.link)
    citation.update_columns(link_http_status: result.status, link_unverifiable: result.unverifiable?,
                            link_checked_at: Time.current)
    checked_citations += 1
    next unless result.unverifiable?

    reclassified += 1
    puts "LexCitation #{citation.id}: #{citation.link} -> unverifiable (HTTP #{result.status})"
  end

  puts "Rechecked #{checked_links} links and #{checked_citations} citation links; " \
       "#{reclassified} now unverifiable"
end

desc 'decode HTML entities baked into LexLink descriptions by the pre-fix html2txt'
task fix_lexicon_link_descriptions: :environment do
  # The only escapes Rails::HTML5::FullSanitizer emits into a text node, so these are the only
  # entities the old html2txt could have baked into a stored description. Deliberately narrower
  # than a full HTMLEntities.decode, which would also rewrite entity-looking text (&copy; and
  # friends) that no sanitizer put there. A single gsub pass gets the ordering right for free:
  # '&amp;lt;' must come out as the literal text '&lt;', not as '<'.
  # Task-local rather than a top-level constant: rake files get loaded more than once (specs
  # rake_require them, console/dev reloads re-read them), and a constant would both warn about
  # being already initialized and leak into the global namespace.
  escapes = { '&nbsp;' => "\u00A0", '&lt;' => '<', '&gt;' => '>', '&amp;' => '&' }.freeze
  fixed = 0

  # `LIKE` is only a cheap pre-filter; the gsub below decides whether anything actually changes.
  LexLink.where('description LIKE ?', '%&%').find_each do |link|
    decoded = link.description.gsub(/&(?:nbsp|lt|gt|amp);/) { |entity| escapes[entity] }
    next if decoded == link.description

    puts "LexLink #{link.id}: #{link.description.inspect} -> #{decoded.inspect}"
    link.update_columns(description: decoded)
    fixed += 1
  end

  puts "#{fixed} link descriptions repaired"
end

desc 'trim the duplicated anchor from lexicon URLs stored before the fix (…/page#sec#sec)'
task fix_lexicon_duplicate_url_anchors: :environment do
  # Every URL column the before_validation hooks now guard, with the columns holding the link
  # checker's verdict about it. backup_url has none -- it usually points at a file we serve
  # ourselves -- so there is nothing to re-check for it, only the URL itself to repair.
  # Task-local rather than a top-level constant: rake files get loaded more than once (specs
  # rake_require them, console/dev reloads re-read them), and a constant would both warn about
  # being already initialized and leak into the global namespace.
  targets = [
    [LexLink, :url, { status: :http_status, unverifiable: :unverifiable, checked_at: :checked_at }],
    [LexCitation, :link,
     { status: :link_http_status, unverifiable: :link_unverifiable, checked_at: :link_checked_at }],
    [LexCitation, :backup_url, nil]
  ].freeze

  checker = Lexicon::CheckExternalLinks.new
  fixed = 0

  targets.each do |model, column, check_columns|
    # `LIKE '%#%#%'` is only a cheap pre-filter for "two or more anchors"; the trim below decides
    # whether those anchors are in fact identical and anything actually changes. Built through Arel
    # so the column name is quoted rather than interpolated into SQL.
    model.where(model.arel_table[column].matches('%#%#%')).find_each do |record|
      stored = record[column]
      trimmed = TrimsDuplicateUrlAnchor.trim(stored)
      next if trimmed == stored

      puts "#{model.name} #{record.id} #{column}: #{stored} -> #{trimmed}"
      attributes = { column => trimmed }

      # The stored verdict was reached on the unparseable URL, so it says nothing about the trimmed
      # one: re-check rather than leave a now-repaired link flagged broken. Local paths are left
      # alone -- the checker has no verdict to offer on a URL we serve ourselves.
      if check_columns && trimmed.start_with?('http://', 'https://')
        result = checker.check_url(trimmed)
        attributes[check_columns[:status]] = result.status
        attributes[check_columns[:unverifiable]] = result.unverifiable?
        attributes[check_columns[:checked_at]] = Time.current
      end

      record.update_columns(attributes)
      fixed += 1
    end
  end

  puts "#{fixed} URLs repaired"
end

task reset_lexicon_ingestion: :environment do
  puts 'Wiping Ingested Lexicon Entries...'
  Chewy.strategy(:atomic) do
    LexFile.find_each do |file|
      file.lex_entry.reset_ingestion!
    end
  end
  puts 'Done.'
end

def download_file(src, fname)
  # removing website prefix if provided (legacy files should use relative paths only but who knows...)
  src = src.gsub(%r{\Ahttp(s)?://#{Lexicon::OLD_LEXICON_PATH}/}, '')

  match = src.match(Lexicon::MigrateAttachment::LEXICON_FILES_REGEX)
  unless match
    @ignored_links << src unless src.start_with?('http') || src.start_with?('hbe/') || src.match(/\d+\.php/)
    return
  end
  full_url = Lexicon::OLD_LEXICON_URL + '/' + src

  uri = begin
    URI.parse(full_url)
  rescue URI::InvalidURIError
    URI.parse(URI.uri_escape(full_url.gsub('%20', ' ')))
  end

  uri.open
rescue OpenURI::HTTPError => e
  @failed_links << [src, fname, e.message]
  puts "Failed to download file: #{src}, error: #{e.message}"
end

task :check_lexicon_attachments, [:dirname] => :environment do |_taskname, args|
  puts 'Trying to download all attachments referenced in Lexicon...'

  @failed_links = []
  @ignored_links = Set.new

  thedir = args.dirname
  die "no such directory #{thedir}" unless Dir.exist?(thedir)
  files = Dir.glob(thedir + '/*.php')
  puts "Reading #{@total} files... "
  files.each do |fname|
    next if IGNORE_LIST.include?(fname[(fname.rindex('/') + 1)..])

    puts "Processing #{fname}..."

    html_doc = File.open(fname) { |f| Nokogiri::HTML(f) }

    html_doc.css('img').each do |img|
      src = img['src']
      download_file(src, fname)
    end

    html_doc.css('a').each do |tag|
      href = tag['href']
      next if href.blank?

      next if href[0] == '#' # local href

      download_file(href, fname)
    end
  rescue ArgumentError => e
    puts "\n#{e} unexpected error in #{fname}. "
    puts e.backtrace.join("\n")
  end

  @ignored_links.each do |link|
    puts "Ignored: #{link}"
  end
  puts "Total ignored links: #{@ignored_links.size}"
  puts '--------------'
  @failed_links.each do |link, fname, error|
    puts "Failed to download: #{link}, referenced in #{fname}, error: #{error}"
  end
  puts "Total failed links: #{@failed_links.size}"
end
