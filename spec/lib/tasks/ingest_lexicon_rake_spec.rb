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
end
