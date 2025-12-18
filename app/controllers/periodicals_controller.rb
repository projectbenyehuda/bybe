# frozen_string_literal: true

class PeriodicalsController < ApplicationController
  def index
    @periodicals = Collection.includes(:collection_items).where(collection_type: 'periodical').order(:title) # TODO: what order would make sense?
    @periodicals_count = @periodicals.count
  end

  def show; end
end
