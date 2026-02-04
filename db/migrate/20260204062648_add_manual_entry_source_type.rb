# frozen_string_literal: true

# Migration to add manual_entry BibSource for manually entered publications
class AddManualEntrySourceType < ActiveRecord::Migration[8.0]
  def up
    # Create the manual_entry bib source
    # source_type 6 corresponds to :manual_entry (added to enum)
    BibSource.create!(
      title: 'Manual Entry',
      source_type: 6,
      status: 0, # enabled
      comments: 'Publications entered manually by editors'
    )
  end

  def down
    BibSource.find_by(title: 'Manual Entry', source_type: 6)&.destroy
  end
end
