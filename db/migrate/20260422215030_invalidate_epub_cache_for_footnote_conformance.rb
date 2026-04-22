# frozen_string_literal: true

class InvalidateEpubCacheForFootnoteConformance < ActiveRecord::Migration[8.1]
  def change
    print 'Removing stale EPUB downloadables to force EPUB3 footnote regeneration... '
    Downloadable.where(doctype: :epub).destroy_all
    puts 'done.'
  end
end
