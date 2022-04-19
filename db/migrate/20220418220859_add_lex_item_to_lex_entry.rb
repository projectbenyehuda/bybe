class AddLexItemToLexEntry < ActiveRecord::Migration[5.2]
  def change
    add_reference :lex_entries, :lex_item, polymorphic: true, index: {:unique=>true}
  end
end
