class AnthologyText < ApplicationRecord
  validates :manifestation, uniqueness: { scope: :anthology_id, allow_nil: true }
  belongs_to :anthology
  belongs_to :manifestation, optional: true
  scope :is_text, -> { where.not(manifestation_id: nil) }
  scope :is_curated, -> { where(manifestation_id: nil) }

  def page_count
    begin
      if cached_page_count.nil? or updated_at < 30.days.ago
        if manifestation_id.nil?
          n = body.split.count / 500.to_f
          self.cached_page_count = n.ceil
        else
          n = manifestation.word_count / 500.to_f
          self.cached_page_count = n.ceil
        end
        save
        touch # update updated_at even if the page count hasn't changed, otherwise we'll keep recalculating
      end
    rescue ActiveRecord::RecordInvalid
      # should only happen with already-invalid records, that were created before the uniqueness requirement. Ignore.
      puts $!
      nil
    end
    return cached_page_count
  end

  def render_html
    markdown = manifestation_id.nil? ? body : manifestation.markdown
    return MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8').gsub(%r{<figcaption>.*?</figcaption>}, '') # remove MMD's automatic figcaptions
  end
end
