class CreateLexPeople < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_people, if_not_exists: true do |t|
      t.string :aliases
      t.boolean :copyrighted
      t.string :birthdate
      t.string :deathdate
      t.text :bio
      t.text :works
      t.text :about

      t.timestamps
    end
    add_index :lex_people, :aliases, if_not_exists: true
    add_index :lex_people, :copyrighted, if_not_exists: true
    add_index :lex_people, :birthdate, if_not_exists: true
    add_index :lex_people, :deathdate, if_not_exists: true
  end
end
