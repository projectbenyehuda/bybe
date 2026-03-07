# frozen_string_literal: true

# Destroy all existing PDF downloadables so they are regenerated with the
# corrected image-scaling CSS (max-width: 100% !important; height: auto !important).
# Without this, previously generated PDFs with cut-off images remain cached.
class DestroyPdfDownloadables < ActiveRecord::Migration[8.0]
  def up
    Downloadable.where(doctype: :pdf).find_each(&:destroy)
  end

  def down
    # No-op: cannot restore previously generated PDF files
  end
end
