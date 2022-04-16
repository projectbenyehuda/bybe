class CreateLexPeople < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_people do |t|
      t.string :aliases
      t.boolean :copyrighted
      t.string :birthdate
      t.string :deathdate
      t.text :bio
      t.text :works
      t.text :about

      t.timestamps
    end
    add_index :lex_people, :aliases
    add_index :lex_people, :copyrighted
    add_index :lex_people, :birthdate
    add_index :lex_people, :deathdate
  end
end
