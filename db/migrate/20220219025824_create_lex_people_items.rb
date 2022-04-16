class CreateLexPeopleItems < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_people_items do |t|
      t.references :lex_person, foreign_key: true
      t.references :item, polymorphic: true

      t.timestamps
    end
  end
end
