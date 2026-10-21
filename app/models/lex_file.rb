# frozen_string_literal: true

# Model representing legacy lexicon file
class LexFile < ApplicationRecord
  PERSON_REGEXP = /^\d{5}\.php$/
  PUBLICATION_REGEXP = /^0\d\d\d\d.?\d\d\d\.php$/
  BIB_REGEXP = /^999.+\.php$/

  enum :status,
       {
         unclassified: 0,
         classified: 1,
         ingested: 2
       },
       prefix: true

  enum :entrytype,
       {
         unknown: 0,
         person: 1,
         text: 2,
         bib: 3,
         other: 4
       },
       prefix: true

  belongs_to :lex_entry

  validates :entrytype, :status, presence: true

  before_save :record_file_size

  # Size of the source file on disk, in KB. Returns nil when there is no recorded
  # path, or when the file cannot be stat'd at all — missing, unreadable, or on an
  # unmounted share — since none of those should break rendering of the files list.
  def file_size_kb
    size = disk_size_bytes
    size && (size / 1024.0).round(1)
  end

  # Refreshes the persisted file_size_bytes (what the files index filters on) from disk.
  def record_file_size
    self.file_size_bytes = disk_size_bytes
  end

  def log_error(message)
    self.error_message ||= ''
    self.error_message += "\n" if self.error_message.present?
    self.error_message += message
  end

  def self.person_filename?(fname)
    entrytype_from_filename(fname) == 'person'
  end

  def self.publication_filename?(fname)
    entrytype_from_filename(fname) == 'text'
  end

  def self.bib_filename?(fname)
    entrytype_from_filename(fname) == 'bib'
  end

  def self.entrytype_from_filename(fname)
    case fname.strip
    when LexFile::BIB_REGEXP
      'bib'
    when LexFile::PERSON_REGEXP
      'person'
    when LexFile::PUBLICATION_REGEXP
      'text'
    else
      'unknown'
    end
  end

  private

  def disk_size_bytes
    return nil if full_path.blank?

    File.size(full_path)
  rescue SystemCallError
    nil
  end
end
