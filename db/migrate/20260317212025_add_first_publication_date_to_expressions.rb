# frozen_string_literal: true

class AddFirstPublicationDateToExpressions < ActiveRecord::Migration[8.0]
  def change
    add_column :expressions, :first_publication_date, :string
    add_column :expressions, :normalized_first_publication_date, :string
  end
end
