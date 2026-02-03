# frozen_string_literal: true

class CleanUpHangingUncollectedCollections < ActiveRecord::Migration[8.0]
  def change
    collections = Collection.uncollected.where(
      'not exists (select 1 from authorities au where au.uncollected_works_collection_id = collections.id)'
    )
    collections.find_each(&:destroy)
  end
end
