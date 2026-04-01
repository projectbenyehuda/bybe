# frozen_string_literal: true

class PopulateLegacyUrlsFromHtmlRecords < ActiveRecord::Migration[8.0]
  def up
    # Populate from HtmlFile records that are Published and linked to at least one Manifestation
    HtmlFile.includes(:manifestations).where(status: 'Published').find_each do |hf|
      next if hf.url.blank?
      next if hf.manifestations.empty?

      from_url = hf.url.start_with?('/') ? hf.url : "/#{hf.url}"
      manifestation = hf.manifestations.first

      LegacyUrl.find_or_create_by!(from_url: from_url) do |lu|
        lu.target = manifestation
        lu.description = "Imported from HtmlFile ##{hf.id}"
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "PopulateLegacyUrls: skipping HtmlFile #{hf.id} (#{hf.url}): #{e.message}"
    end

    # Populate from HtmlDir records linked to a person who has an authority
    HtmlDir.includes(person: :authority).find_each do |hd|
      next if hd.path.blank?
      next if hd.person.nil?

      authority = hd.person.authority
      next if authority.nil?

      from_url = "/#{hd.path}"

      LegacyUrl.find_or_create_by!(from_url: from_url) do |lu|
        lu.target = authority
        lu.description = "Imported from HtmlDir ##{hd.id}"
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "PopulateLegacyUrls: skipping HtmlDir #{hd.id} (#{hd.path}): #{e.message}"
    end
  end

  def down
    LegacyUrl.where("description LIKE 'Imported from Html%'").delete_all
  end
end
