# frozen_string_literal: true

class AddTitleLinksToLexPersonWorks < ActiveRecord::Migration[8.1]
  def change
    add_column :lex_person_works, :title_links, :json
  end
end
