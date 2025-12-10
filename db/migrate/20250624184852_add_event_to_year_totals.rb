# frozen_string_literal: true
class AddEventToYearTotals < ActiveRecord::Migration[6.1]
  def change
    add_column :year_totals, :event, :string, if_not_exists: true

    execute "update year_totals set event = 'view'"

    change_column_null :year_totals, :event, null: false
  end
end
