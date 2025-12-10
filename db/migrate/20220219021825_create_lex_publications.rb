class CreateLexPublications < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_publications, if_not_exists: true do |t|
      t.text :description
      t.text :toc
      t.boolean :az_navbar

      t.timestamps
    end
  end
end
