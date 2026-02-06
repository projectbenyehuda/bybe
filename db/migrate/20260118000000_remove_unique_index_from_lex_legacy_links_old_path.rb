class RemoveUniqueIndexFromLexLegacyLinksOldPath < ActiveRecord::Migration[8.0]
  def up
    remove_index :lex_legacy_links, name: "index_lex_legacy_links_on_old_path"
    add_index :lex_legacy_links, :old_path, name: "index_lex_legacy_links_on_old_path"
  end

  def down
    remove_index :lex_legacy_links, name: "index_lex_legacy_links_on_old_path"
    add_index :lex_legacy_links, :old_path, name: "index_lex_legacy_links_on_old_path", unique: true
  end
end
