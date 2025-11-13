class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  ALLOWED_NAMES = %w(view download page_view search clicked_tag).freeze

  self.table_name = 'ahoy_events'

  belongs_to :visit
  belongs_to :user, optional: true

  # For some events we store record type and id in JSON properties, and for convenience we've added
  # two virtual columns `item_id` and `item_type` to table so we can use it to establish polymorphic relation
  belongs_to :item, optional: true, polymorphic: true

  validates :name, presence: true, inclusion: { in: ALLOWED_NAMES }
end
