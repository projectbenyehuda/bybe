class AddPersonToLexPerson < ActiveRecord::Migration[5.2]
  def change
    add_reference :lex_people, :person, foreign_key: true, type: :integer
  end
end
