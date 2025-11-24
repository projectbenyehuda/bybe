# frozen_string_literal: true

class ReIndexAuthorities < ActiveRecord::Migration[8.0]
  def change
    puts 'Reindexing Authorities...'
    AuthoritiesIndex.reset!
  end
end
