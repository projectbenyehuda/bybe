# frozen_string_literal: true

# Sidekiq job to asynchronously refresh uncollected works collections for given authorities
class RefreshUncollectedWorksCollectionJob
  include Sidekiq::Job

  def perform(uncollected_works_collection_ids)
    Authority.where(uncollected_works_collection_id: uncollected_works_collection_ids).find_each do |authority|
      RefreshUncollectedWorksCollection.call(authority)
    end
  end
end
