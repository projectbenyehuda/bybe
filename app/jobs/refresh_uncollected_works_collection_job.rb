# frozen_string_literal: true

# Asynchronously refreshes uncollected works collections for given authorities.
class RefreshUncollectedWorksCollectionJob < ApplicationJob
  def perform(uncollected_works_collection_ids)
    Authority.where(uncollected_works_collection_id: uncollected_works_collection_ids).find_each do |authority|
      RefreshUncollectedWorksCollection.call(authority)
    end
  end
end
