# frozen_string_literal: true

class RemoveMobiDownloadables < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up do
        # Remove all mobi downloadables
        rel = Downloadable.where(doctype: 4)
        puts "Removing #{rel.count} MOBI downloadables..."
        rel.find_each do |downloadable|
          downloadable.destroy!
        end
      end

      dir.down do
      end
    end
  end
end
