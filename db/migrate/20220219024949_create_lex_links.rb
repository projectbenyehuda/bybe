class CreateLexLinks < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_links do |t|
      t.string :url
      t.string :description
      t.integer :status
      t.references :item, polymorphic: true

      t.timestamps
    end
  end
end
