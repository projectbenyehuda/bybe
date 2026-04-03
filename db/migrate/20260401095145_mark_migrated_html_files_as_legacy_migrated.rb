# frozen_string_literal: true

class MarkMigratedHtmlFilesAsLegacyMigrated < ActiveRecord::Migration[8.0]
  def up
    # Mark HtmlFile records whose URLs were migrated to LegacyUrl
    migrated_urls = LegacyUrl.where("description LIKE 'Imported from HtmlFile%'").pluck(:from_url)
    HtmlFile.where(url: migrated_urls).update_all(status: 'Migrated')
  end

  def down
    # Restore status to 'Published' for records we marked as Migrated
    migrated_urls = LegacyUrl.where("description LIKE 'Imported from HtmlFile%'").pluck(:from_url)
    HtmlFile.where(url: migrated_urls, status: 'Migrated').update_all(status: 'Published')
  end
end
