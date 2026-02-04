# frozen_string_literal: true

# Migration to add manual_entry BibSource for manually entered publications
class AddManualEntrySourceType < ActiveRecord::Migration[8.0]
  def up
    # Create or update the manual_entry bib source
    # source_type 6 corresponds to :manual_entry (added to enum)
    # Using find_or_create_by to make migration idempotent
    bib_source = BibSource.find_or_create_by!(title: 'Manual Entry', source_type: 6) do |bs|
      bs.status = 0 # enabled
      bs.comments = 'Publications entered manually by editors'
    end

    # Update attributes if record already exists
    bib_source.update!(
      status: 0, # enabled
      comments: 'Publications entered manually by editors'
    )
  end

  def down
    BibSource.find_by(title: 'Manual Entry', source_type: 6)&.destroy
  end
end
