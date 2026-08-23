# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'ingest_lexicon rake task' do # rubocop:disable RSpec/DescribeClass
  before(:all) do
    Rake.application.rake_require 'tasks/ingest_lexicon'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['ingest_lexicon'] }
  let(:fixtures_dir) { Rails.root.join('spec/fixtures/files/lexicon') }
  let(:work_dir) { Dir.mktmpdir }

  before { task.reenable }

  after { FileUtils.remove_entry(work_dir) }

  # Copies the given fixture php filenames into an isolated working directory
  # so the task only processes the files relevant to the example.
  def stage(*filenames)
    filenames.each { |name| FileUtils.cp(fixtures_dir.join(name), File.join(work_dir, name)) }
  end

  def entry_for(fname)
    LexFile.find_by(fname: fname)&.lex_entry
  end

  it 'marks a five-digit filename as a main entry' do
    stage('00020.php')

    task.invoke(work_dir)

    expect(entry_for('00020.php').main).to be true
  end

  it 'marks a non-five-digit numeric filename as a secondary (non-main) entry' do
    stage('02645001.php')

    task.invoke(work_dir)

    expect(entry_for('02645001.php').main).to be false
  end

  it 'refreshes the title of a not-yet-migrated entry whose source file changed' do
    stage('00020.php')
    task.invoke(work_dir)
    entry = entry_for('00020.php')
    original_title = entry.title
    entry.update!(title: 'כותרת ישנה')
    FileUtils.touch(File.join(work_dir, '00020.php'), mtime: 1.hour.from_now.to_time)

    task.reenable
    task.invoke(work_dir)

    expect(entry.reload.title).to eq(original_title)
  end

  describe 'flag_unmigrated_citations' do
    let(:flag_task) { Rake::Task['flag_unmigrated_citations'] }

    before { flag_task.reenable }

    # A person entry that migrated with no citations at all, from the given source file.
    def migrated_person_without_citations(fixture)
      create(:lex_file, :person, status: :ingested, entry_status: :draft, fname: fixture,
                                 full_path: fixtures_dir.join(fixture).to_s)
    end

    it 'flags an entry whose bibliography section produced no citations' do
      lex_file = migrated_person_without_citations('unparsable_citations.php')

      flag_task.invoke

      expect(lex_file.reload.error_message).to eq(Lexicon::FlagUnmigratedCitations::MESSAGE_KEY)
    end

    it 'leaves entries whose bibliography section is genuinely empty alone' do
      lex_file = migrated_person_without_citations('j9u_only.php')

      flag_task.invoke

      expect(lex_file.reload.error_message).to be_nil
    end

    it 'carries on past a file it cannot read' do
      unreadable = migrated_person_without_citations('00020.php')
      flaggable = migrated_person_without_citations('unparsable_citations.php')
      allow(Lexicon::HtmlUtils).to receive(:parse_file).and_call_original
      allow(Lexicon::HtmlUtils).to receive(:parse_file).with(unreadable.full_path).and_raise(Errno::EACCES)

      flag_task.invoke

      expect(flaggable.reload.error_message).to eq(Lexicon::FlagUnmigratedCitations::MESSAGE_KEY)
      expect(unreadable.reload.error_message).to be_nil
    end

    it 'leaves entries that did migrate citations alone' do
      lex_file = migrated_person_without_citations('unparsable_citations.php')
      lex_file.lex_entry.lex_item.citations << build(:lex_citation)

      flag_task.invoke

      expect(lex_file.reload.error_message).to be_nil
    end
  end

  describe 'recheck_broken_lexicon_links' do
    let(:recheck_task) { Rake::Task['recheck_broken_lexicon_links'] }
    let(:checker) { instance_double(Lexicon::CheckExternalLinks) }

    before do
      recheck_task.reenable
      allow(Lexicon::CheckExternalLinks).to receive(:new).and_return(checker)
      allow(checker).to receive(:check_url).and_return(link_check_result(200))
    end

    def broken_link(url)
      create(:lex_link, url: url, http_status: 403, checked_at: 1.day.ago)
    end

    def broken_citation_link(url)
      create(:lex_citation, person: create(:lex_person), link: url,
                            link_http_status: 403, link_checked_at: 1.day.ago)
    end

    it 'flags a link whose host now answers with a bot challenge' do
      link = broken_link('https://www.nli.org.il/he/archives/NNL_ALEPH000000001')
      allow(checker).to receive(:check_url).and_return(link_check_result(403, unverifiable: true))

      recheck_task.invoke

      expect(link.reload.unverifiable).to be true
    end

    it 'flags a citation link whose host now answers with a bot challenge' do
      citation = broken_citation_link('https://www.nli.org.il/he/newspapers/example')
      allow(checker).to receive(:check_url).and_return(link_check_result(403, unverifiable: true))

      recheck_task.invoke

      expect(citation.reload.link_unverifiable).to be true
    end

    # Regression: the summary line used to call .count on the two relations after the loops had
    # already moved rows out of their scopes, so it re-queried the mutated rows and reported far
    # fewer records than it had actually rechecked -- here, zero of each.
    it 'reports what it rechecked, not what still matches the scope afterwards' do
      broken_link('https://recovered.example.com/a')
      broken_citation_link('https://recovered.example.com/b')

      expect { recheck_task.invoke }
        .to output(/Rechecked 1 links and 1 citation links; 0 now unverifiable/).to_stdout
    end

    it 'counts records it reclassified, which have also left the scope' do
      broken_link('https://www.nli.org.il/he/archives/a')
      broken_citation_link('https://www.nli.org.il/he/newspapers/b')
      allow(checker).to receive(:check_url).and_return(link_check_result(403, unverifiable: true))

      expect { recheck_task.invoke }
        .to output(/Rechecked 1 links and 1 citation links; 2 now unverifiable/).to_stdout
    end

    it 'skips an unreachable link (nil status) rather than spending a timeout on it' do
      create(:lex_link, url: 'https://dead.example.com/x', http_status: nil, checked_at: 1.day.ago)

      recheck_task.invoke

      expect(checker).not_to have_received(:check_url)
    end

    it 'skips links already flagged unverifiable' do
      create(:lex_link, url: 'https://www.nli.org.il/he/archives/x', http_status: 403,
                        unverifiable: true, checked_at: 1.day.ago)

      recheck_task.invoke

      expect(checker).not_to have_received(:check_url)
    end

    it 'clears the flag on a link that now answers normally' do
      link = broken_link('https://recovered.example.com/a')

      recheck_task.invoke

      expect(link.reload).to have_attributes(http_status: 200, unverifiable: false)
    end
  end

  describe 'fix_lexicon_titles' do
    let(:fix_task) { Rake::Task['fix_lexicon_titles'] }
    let(:source_file) { fixtures_dir.join('00020.php') }
    let(:correct_title) { Lexicon::ExtractTitle.call(source_file) }

    before { fix_task.reenable }

    # Reproduces what libxml2's ISO-8859-1 fallback used to make of UTF-8 Hebrew
    def mangle(str)
      str.b.force_encoding('ISO-8859-1').encode('UTF-8')
    end

    def raw_entry_with_title(title)
      lex_file = create(:lex_file, :person, entry_status: :raw, fname: '00020.php',
                                            full_path: source_file.to_s)
      lex_file.lex_entry.tap { |entry| entry.update!(title: title) }
    end

    it 're-extracts a mangled title from the source file' do
      entry = raw_entry_with_title(mangle(correct_title))

      fix_task.invoke

      expect(entry.reload.title).to eq(correct_title)
    end

    it 'leaves a well-formed title alone even when it differs from the source file' do
      entry = raw_entry_with_title('כותרת שתוקנה ביד')

      fix_task.invoke

      expect(entry.reload.title).to eq('כותרת שתוקנה ביד')
    end
  end
end
