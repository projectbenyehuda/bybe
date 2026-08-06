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
